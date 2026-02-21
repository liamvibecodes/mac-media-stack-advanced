#!/bin/bash
# Music Setup Helper (Lidarr + Tidarr)
# Creates music directories and Tidarr download config.
# Run this before: docker compose --profile music up -d

set -e

YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

echo ""
echo "=============================="
echo "  Music Setup (Lidarr + Tidarr)"
echo "=============================="
echo ""

CURRENT_USER=$(whoami)
HOME_DIR=$(eval echo ~$CURRENT_USER)
MEDIA_DIR="$HOME_DIR/Media"

# Create directories
echo "Creating music directories..."
mkdir -p "$MEDIA_DIR"/Music
mkdir -p "$MEDIA_DIR"/Downloads/tidarr
mkdir -p "$MEDIA_DIR"/config/lidarr
mkdir -p "$MEDIA_DIR"/config/tidarr/.tiddl
echo -e "  ${GREEN}Done${NC}"
echo ""

# Create tiddl config if not present
TIDDL_CONFIG="$MEDIA_DIR/config/tidarr/.tiddl/config.toml"
if [[ ! -f "$TIDDL_CONFIG" ]]; then
    echo "Creating Tidarr download config..."
    cat > "$TIDDL_CONFIG" << 'TOML'
# Tidarr/Tiddl Download Configuration
# Docs: https://github.com/oskvr37/tiddl

enable_cache = true
debug = false

[templates]
default = "{album.artist}/{album.title}/{item.number:02d} {item.title_version}"
track = "{album.artist}/{album.title}/{item.number:02d} {item.title_version}"
video = "{album.artist}/videos/{item.artist} - {item.title}"
album = "{album.artist}/{album.title}/{item.number:02d} {item.title_version}"
playlist = "playlists/{playlist.title}/{playlist.index:02d}. {item.artist} - {item.title_version}"
mix = "mixes/{playlist.title}/{playlist.index:02d}. {item.artist} - {item.title_version}"

[download]
# max = up to 24-bit/192kHz FLAC, high = 16-bit/44.1kHz FLAC
# normal = 320kbps AAC, low = 96kbps AAC
track_quality = "max"
video_quality = "fhd"
skip_existing = true
threads_count = 4
download_path = "/music"
scan_path = "/music"
singles_filter = "none"
videos_filter = "none"
update_mtime = false
rewrite_metadata = false

[metadata]
enable = true
lyrics = false
cover = true

[cover]
save = false
size = 1280
allowed = []

[m3u]
save = false
allowed = []
TOML
    echo -e "  ${GREEN}Done${NC}"
else
    echo -e "${YELLOW}Note:${NC} Tidarr config already exists. Skipping."
fi

echo ""
echo "=============================="
echo "  Music setup complete!"
echo "=============================="
echo ""
echo "Next steps:"
echo "  1. Start music services:"
echo "     docker compose --profile music up -d"
echo ""
echo "  2. Authenticate with Tidal:"
echo "     Open http://localhost:8484"
echo "     Follow the device login flow to link your Tidal account"
echo ""
echo "  3. Configure Lidarr:"
echo "     Open http://localhost:8686"
echo "     Add root folder: /music"
echo "     Add Tidarr as download client (SABnzbd, host: tidarr, port: 8484)"
echo "     Add Tidarr as indexer (Newznab, URL: http://tidarr:8484)"
echo ""
echo -e "  ${CYAN}Tip:${NC} Add 'export COMPOSE_PROFILES=music' to your shell profile"
echo "  so music services start with every 'docker compose up -d'"
echo ""
