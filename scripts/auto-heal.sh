#!/bin/bash
# Media Stack Auto-Healer
# Runs hourly via launchd. Checks VPN and container health, restarts what's broken.

BASE_DIR="$HOME/Media"
LOG_DIR="$BASE_DIR/logs"
mkdir -p "$LOG_DIR"
LOG="$LOG_DIR/auto-heal.log"

timestamp() { date "+%Y-%m-%d %H:%M:%S"; }
log() { echo "$(timestamp) $1" >> "$LOG"; }

# Trim log
if [[ -f "$LOG" ]] && [[ $(wc -l < "$LOG") -gt 500 ]]; then
    tail -500 "$LOG" > "$LOG.tmp" && mv "$LOG.tmp" "$LOG"
fi

log "--- Health check started ---"

if ! docker info &>/dev/null; then
    log "ERROR: Docker not running"
    exit 1
fi

HEALED=0

# Check VPN
vpn_ip=$(docker exec gluetun sh -c 'wget -qO- --timeout=5 https://ipinfo.io/ip' 2>/dev/null)
local_ip=$(curl -s --max-time 5 https://ipinfo.io/ip 2>/dev/null)

if [[ -z "$vpn_ip" || "$vpn_ip" == "$local_ip" ]]; then
    log "WARN: VPN issue. Restarting gluetun..."
    docker restart gluetun >> "$LOG" 2>&1
    sleep 15
    vpn_ip=$(docker exec gluetun sh -c 'wget -qO- --timeout=5 https://ipinfo.io/ip' 2>/dev/null)
    if [[ -n "$vpn_ip" && "$vpn_ip" != "$local_ip" ]]; then
        log "OK: VPN recovered (IP: $vpn_ip)"
    else
        log "ERROR: VPN still down after restart"
    fi
    ((HEALED++))
else
    log "OK: VPN active (IP: $vpn_ip)"
fi

# Check containers
for name in gluetun qbittorrent prowlarr sonarr radarr bazarr flaresolverr seerr tdarr unpackerr recyclarr; do
    state=$(docker inspect -f '{{.State.Status}}' "$name" 2>/dev/null)
    if [[ "$state" != "running" ]]; then
        log "WARN: $name is $state. Starting..."
        docker start "$name" >> "$LOG" 2>&1
        ((HEALED++))
    fi
done

if [[ $HEALED -gt 0 ]]; then
    log "Healed $HEALED issue(s)"
else
    log "All healthy"
fi
