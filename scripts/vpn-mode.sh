#!/bin/bash
# Manual VPN provider switcher: proton, nord, or status.
# Usage: vpn-mode.sh {proton|nord|status}

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
COMPOSE_FILE="$SCRIPT_DIR/docker-compose.yml"
NORD_OVERRIDE="$SCRIPT_DIR/docker-compose.nord-fallback.yml"

DOCKER_BIN="$(command -v docker || echo /opt/homebrew/bin/docker)"

status() {
    local provider public_ip forward_port
    provider="$("$DOCKER_BIN" inspect gluetun --format '{{range .Config.Env}}{{println .}}{{end}}' 2>/dev/null | grep '^VPN_SERVICE_PROVIDER=' | cut -d= -f2 || true)"
    public_ip="$("$DOCKER_BIN" exec gluetun sh -lc 'cat /tmp/gluetun/ip 2>/dev/null || true' 2>/dev/null || true)"
    forward_port="$("$DOCKER_BIN" exec gluetun sh -lc 'cat /tmp/gluetun/forwarded_port 2>/dev/null || true' 2>/dev/null || true)"
    echo "provider=${provider:-unknown}"
    echo "public_ip=${public_ip:-unknown}"
    echo "forwarded_port=${forward_port:-none}"
}

case "${1:-status}" in
    proton)
        "$DOCKER_BIN" compose -f "$COMPOSE_FILE" up -d gluetun qbittorrent
        status
        ;;
    nord)
        if [[ ! -f "$SCRIPT_DIR/.env.nord" ]]; then
            echo "Missing .env.nord (copy from .env.nord.example)"
            exit 1
        fi
        "$DOCKER_BIN" compose -f "$COMPOSE_FILE" -f "$NORD_OVERRIDE" up -d gluetun qbittorrent
        status
        ;;
    status)
        status
        ;;
    *)
        echo "Usage: $0 {proton|nord|status}"
        exit 1
        ;;
esac
