#!/bin/bash
# Mac Media Stack (Advanced) - One-Shot Installer
# Usage: curl -fsSL https://raw.githubusercontent.com/liamvibecodes/mac-media-stack-advanced/main/bootstrap.sh | bash

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo ""
echo "======================================="
echo "  Mac Media Stack Installer (Advanced)"
echo "======================================="
echo ""

# Check Docker
if ! docker info &>/dev/null; then
    echo -e "${RED}Docker Desktop is not running.${NC}"
    echo "Install it from https://www.docker.com/products/docker-desktop/"
    echo "Open it, wait for it to start, then run this again."
    exit 1
fi
echo -e "${GREEN}OK${NC}  Docker Desktop is running"

# Check Plex
if [[ -d "/Applications/Plex Media Server.app" ]] || pgrep -x "Plex Media Server" &>/dev/null; then
    echo -e "${GREEN}OK${NC}  Plex detected"
else
    echo -e "${YELLOW}WARN${NC}  Plex not detected. Install from https://www.plex.tv/media-server-downloads/"
    echo "  You can continue and install Plex later."
fi

# Check git
if ! command -v git &>/dev/null; then
    echo -e "${YELLOW}..${NC}  git not found, installing Command Line Tools..."
    xcode-select --install 2>/dev/null || true
    echo "  Click Install when prompted, then run this again."
    exit 1
fi

echo ""

# Clone
INSTALL_DIR="$HOME/mac-media-stack-advanced"
if [[ -d "$INSTALL_DIR" ]]; then
    echo -e "${YELLOW}Note:${NC} $INSTALL_DIR already exists. Pulling latest..."
    if ! git -C "$INSTALL_DIR" pull --ff-only; then
        echo -e "${RED}Failed to update existing repo at $INSTALL_DIR.${NC}"
        echo "Resolve local git issues, then re-run bootstrap."
        echo "Suggested check: cd $INSTALL_DIR && git status"
        exit 1
    fi
else
    echo -e "${CYAN}Cloning repo...${NC}"
    git clone https://github.com/liamvibecodes/mac-media-stack-advanced.git "$INSTALL_DIR"
fi
cd "$INSTALL_DIR"

echo ""

# Setup
echo -e "${CYAN}Running setup...${NC}"
bash scripts/setup.sh

echo ""

# VPN keys
if grep -q "your_wireguard_private_key_here" .env 2>/dev/null; then
    echo -e "${CYAN}VPN Configuration${NC}"
    echo ""
    read -s -p "  WireGuard Private Key: " vpn_key
    echo ""
    read -p "  WireGuard Address (e.g. 10.2.0.2/32): " vpn_addr

    if [[ -n "$vpn_key" && -n "$vpn_addr" ]]; then
        sed -i '' "s|WIREGUARD_PRIVATE_KEY=.*|WIREGUARD_PRIVATE_KEY=$vpn_key|" .env
        sed -i '' "s|WIREGUARD_ADDRESSES=.*|WIREGUARD_ADDRESSES=$vpn_addr|" .env
        echo -e "  ${GREEN}VPN keys saved${NC}"
    else
        echo -e "  ${YELLOW}Skipped.${NC} Edit .env manually: open -a TextEdit $INSTALL_DIR/.env"
    fi
fi

echo ""

# Start stack
echo -e "${CYAN}Starting media stack (first run downloads ~3-5 GB)...${NC}"
echo ""
docker compose up -d

echo ""
echo "Waiting 30 seconds for services to initialize..."
sleep 30

# Configure
echo ""
bash scripts/configure.sh

# Install automation
echo ""
echo -e "${CYAN}Installing automation jobs...${NC}"
bash scripts/install-launchd-jobs.sh

echo ""
echo "======================================="
echo -e "  ${GREEN}Installation complete!${NC}"
echo "======================================="
echo ""
echo "  Seerr:  http://localhost:5055"
echo "  Plex:   http://localhost:32400/web"
echo "  Tdarr:  http://localhost:8265"
echo ""
echo "  Remaining manual steps:"
echo "    1. Set up Plex libraries (Movies: ~/Media/Movies, TV: ~/Media/TV Shows)"
echo "    2. Edit ~/Media/config/recyclarr/recyclarr.yml with your API keys"
echo "    3. Edit ~/Media/config/kometa/config.yml with Plex token + TMDB key"
echo "    4. Update .env with Unpackerr API keys, then: docker compose restart unpackerr"
echo "    5. Configure Tdarr at http://localhost:8265"
echo ""
echo "  Optional - Music (Lidarr + Tidarr):"
echo "    bash scripts/setup-music.sh"
echo "    docker compose --profile music up -d"
echo "    Then open http://localhost:8484 to authenticate with Tidal"
echo ""
echo "  API keys were printed by the configure step above. Scroll up if needed."
echo ""
