#!/bin/bash
# Media Stack Health Check (Advanced)
# Checks all containers including Tdarr, Recyclarr, Unpackerr, Kometa.

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0

check_service() {
    local name="$1" url="$2"
    status=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$url" 2>/dev/null)
    if [[ "$status" =~ ^(200|301|302)$ ]]; then
        echo -e "  ${GREEN}OK${NC}  $name"
        ((PASS++))
    else
        echo -e "  ${RED}FAIL${NC}  $name (HTTP $status)"
        ((FAIL++))
    fi
}

echo ""
echo "=============================="
echo "  Media Stack Health Check"
echo "=============================="
echo ""

if docker info &>/dev/null; then
    echo -e "  ${GREEN}OK${NC}  Docker Desktop"
    ((PASS++))
else
    echo -e "  ${RED}FAIL${NC}  Docker Desktop (not running)"
    exit 1
fi
echo ""

echo "Containers:"
for name in gluetun qbittorrent prowlarr sonarr radarr bazarr flaresolverr seerr tdarr unpackerr recyclarr kometa lidarr tidarr; do
    state=$(docker inspect -f '{{.State.Status}}' "$name" 2>/dev/null)
    if [[ "$state" == "running" ]]; then
        echo -e "  ${GREEN}OK${NC}  $name"
        ((PASS++))
    elif [[ "$name" == "kometa" ]] && [[ "$state" == "exited" || "$state" == "created" ]]; then
        # Kometa runs as a one-shot, exited is normal
        echo -e "  ${YELLOW}OK${NC}  $name (one-shot, not always running)"
    elif [[ "$name" == "lidarr" || "$name" == "tidarr" ]] && [[ -z "$state" ]]; then
        echo -e "  ${YELLOW}SKIP${NC}  $name (music profile not enabled)"
    else
        echo -e "  ${RED}FAIL${NC}  $name (${state:-not found})"
        ((FAIL++))
    fi
done

watchtower_state=$(docker inspect -f '{{.State.Status}}' watchtower 2>/dev/null || true)
if [[ "$watchtower_state" == "running" ]]; then
    echo -e "  ${GREEN}OK${NC}  watchtower (autoupdate profile enabled)"
    ((PASS++))
else
    echo -e "  ${YELLOW}SKIP${NC}  watchtower (optional; enable with --profile autoupdate)"
fi

echo ""
echo "Web UIs:"
check_service "qBittorrent" "http://localhost:8080"
check_service "Prowlarr" "http://localhost:9696"
check_service "Sonarr" "http://localhost:8989"
check_service "Radarr" "http://localhost:7878"
check_service "Bazarr" "http://localhost:6767"
check_service "Seerr" "http://localhost:5055"
check_service "Tdarr" "http://localhost:8265"

# Music services (only if profile enabled)
if docker inspect -f '{{.State.Status}}' lidarr &>/dev/null; then
    check_service "Lidarr" "http://localhost:8686"
    check_service "Tidarr" "http://localhost:8484"
fi

echo ""
echo "VPN:"
vpn_ip=$(docker exec gluetun sh -c 'wget -qO- https://ipinfo.io/ip' 2>/dev/null)
local_ip=$(curl -s https://ipinfo.io/ip 2>/dev/null)
if [[ -n "$vpn_ip" && "$vpn_ip" != "$local_ip" ]]; then
    echo -e "  ${GREEN}OK${NC}  VPN active (IP: $vpn_ip)"
    ((PASS++))
elif [[ -z "$vpn_ip" ]]; then
    echo -e "  ${RED}FAIL${NC}  VPN not connected"
    ((FAIL++))
else
    echo -e "  ${RED}FAIL${NC}  VPN IP matches real IP"
    ((FAIL++))
fi

echo ""
echo "Plex:"
plex_status=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "http://localhost:32400/web" 2>/dev/null)
if [[ "$plex_status" =~ ^(200|301|302)$ ]]; then
    echo -e "  ${GREEN}OK${NC}  Plex"
    ((PASS++))
else
    echo -e "  ${YELLOW}SKIP${NC}  Plex not detected"
fi

echo ""
echo "=============================="
echo "  Results: ${GREEN}$PASS passed${NC}, ${RED}$FAIL failed${NC}"
echo "=============================="
echo ""
