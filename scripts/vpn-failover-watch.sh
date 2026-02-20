#!/bin/bash
# VPN Failover Watcher
# Auto-switches between ProtonVPN and NordVPN on sustained tunnel failure.
# Runs every 2 minutes via launchd. Requires .env.nord for Nord credentials.

set -euo pipefail

BASE_DIR="$HOME/Media"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
STATE_FILE="$BASE_DIR/state/vpn-failover-state.json"
LOG_FILE="$BASE_DIR/logs/vpn-failover.log"
LOCK_DIR="/tmp/com.media-stack.vpn-failover.lock"
VPN_MODE_SCRIPT="$SCRIPT_DIR/vpn-mode.sh"

THRESHOLD="${VPN_FAILOVER_THRESHOLD:-3}"
COOLDOWN_SECONDS="${VPN_FAILOVER_COOLDOWN_SECONDS:-900}"

DOCKER_BIN="$(command -v docker || echo /opt/homebrew/bin/docker)"
REASON=""

log() { mkdir -p "$(dirname "$LOG_FILE")"; echo "$(date '+%Y-%m-%d %H:%M:%S') $*" >> "$LOG_FILE"; }

# Lock to prevent overlapping runs
if ! mkdir "$LOCK_DIR" 2>/dev/null; then exit 0; fi
trap 'rmdir "$LOCK_DIR" 2>/dev/null || true' EXIT

# Init state file
mkdir -p "$BASE_DIR/state"
if [[ ! -f "$STATE_FILE" ]]; then
    echo '{"vpn_fail_streak":0,"last_switch_epoch":0,"last_switch_target":"","last_reason":"init","last_provider":"unknown"}' > "$STATE_FILE"
fi

get_provider() {
    "$DOCKER_BIN" inspect gluetun --format '{{range .Config.Env}}{{println .}}{{end}}' 2>/dev/null | grep '^VPN_SERVICE_PROVIDER=' | cut -d= -f2 || true
}

check_health() {
    if ! "$DOCKER_BIN" ps --format '{{.Names}}' 2>/dev/null | grep -qx 'gluetun'; then
        REASON="gluetun_not_running"; return 1
    fi
    if ! "$DOCKER_BIN" ps --format '{{.Names}}' 2>/dev/null | grep -qx 'qbittorrent'; then
        REASON="qbittorrent_not_running"; return 1
    fi
    if ! curl -fsS --max-time 6 'http://127.0.0.1:8080/' >/dev/null 2>&1; then
        REASON="qb_webui_unreachable"; return 1
    fi
    local vpn_ip
    vpn_ip="$("$DOCKER_BIN" exec gluetun sh -lc 'wget -qO- --timeout=8 https://api.ipify.org 2>/dev/null || true' 2>/dev/null || true)"
    if [[ -z "$vpn_ip" ]]; then
        REASON="vpn_egress_unreachable"; return 1
    fi
    REASON="ok"; return 0
}

now="$(date +%s)"
provider="$(get_provider)"
provider="${provider:-unknown}"

# Read state
streak=$(python3 -c "import json; d=json.load(open('$STATE_FILE')); print(d.get('vpn_fail_streak',0))" 2>/dev/null || echo 0)
last_switch_epoch=$(python3 -c "import json; d=json.load(open('$STATE_FILE')); print(d.get('last_switch_epoch',0))" 2>/dev/null || echo 0)

if check_health; then
    if [[ "$streak" -gt 0 ]]; then
        log "[OK] $provider recovered after $streak failed checks"
    fi
    python3 -c "
import json
d={'vpn_fail_streak':0,'last_switch_epoch':$last_switch_epoch,'last_switch_target':'','last_reason':'ok','last_provider':'$provider'}
json.dump(d,open('$STATE_FILE','w'),indent=2)
" 2>/dev/null
    exit 0
fi

streak=$((streak + 1))
log "[WARN] $provider health failed streak=$streak/$THRESHOLD reason=$REASON"

if [[ "$streak" -ge "$THRESHOLD" ]]; then
    elapsed=$((now - last_switch_epoch))
    if [[ "$elapsed" -lt "$COOLDOWN_SECONDS" ]]; then
        log "[WARN] failover suppressed by cooldown (${elapsed}s < ${COOLDOWN_SECONDS}s)"
    else
        if [[ "$provider" == "protonvpn" ]]; then
            target="nord"
        else
            target="proton"
        fi
        if output="$("$VPN_MODE_SCRIPT" "$target" 2>&1)"; then
            log "[ACTION] switched from $provider to $target reason=$REASON"
            streak=0
            last_switch_epoch="$now"
        else
            log "[ERROR] switch failed: $output"
        fi
    fi
fi

python3 -c "
import json
d={'vpn_fail_streak':$streak,'last_switch_epoch':$last_switch_epoch,'last_switch_target':'','last_reason':'$REASON','last_provider':'$provider'}
json.dump(d,open('$STATE_FILE','w'),indent=2)
" 2>/dev/null
