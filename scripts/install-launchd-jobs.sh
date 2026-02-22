#!/bin/bash
# Installs all launchd automation jobs:
# - Auto-heal (hourly)
# - Nightly backup
# - Download watchdog (every 15 min)
# - VPN failover (every 2 min, optional)
# - Kometa (every 4 hours)

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
LAUNCH_DIR="$HOME/Library/LaunchAgents"
LOG_DIR="$HOME/Media/logs/launchd"
PREFIX="com.media-stack"

mkdir -p "$LAUNCH_DIR"
mkdir -p "$LOG_DIR"

install_plist() {
    local name="$1" interval="$2" script="$3" run_at_load="${4:-true}"
    local plist="$LAUNCH_DIR/$PREFIX.$name.plist"
    local runner="/bin/bash"

    if [[ "$script" == *.py ]]; then
        runner="$(command -v python3 || echo /usr/bin/python3)"
    fi

    cat > "$plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$PREFIX.$name</string>
    <key>ProgramArguments</key>
    <array>
        <string>$runner</string>
        <string>$script</string>
    </array>
    <key>WorkingDirectory</key>
    <string>$PROJECT_DIR</string>
    <key>StartInterval</key>
    <integer>$interval</integer>
    <key>RunAtLoad</key>
    <$run_at_load/>
    <key>StandardOutPath</key>
    <string>$LOG_DIR/$name.out.log</string>
    <key>StandardErrorPath</key>
    <string>$LOG_DIR/$name.err.log</string>
</dict>
</plist>
EOF

    launchctl unload "$plist" 2>/dev/null || true
    launchctl load "$plist"
    echo -e "  ${GREEN}OK${NC}  $name (every ${interval}s)"
}

echo ""
echo "=============================="
echo "  Installing Automation Jobs"
echo "=============================="
echo ""

install_plist "auto-heal" 3600 "$SCRIPT_DIR/auto-heal.sh"
install_plist "backup" 86400 "$SCRIPT_DIR/backup.sh"
install_plist "download-watchdog" 900 "$SCRIPT_DIR/download-watchdog.py" "false"

# Kometa one-shot (every 4 hours = 14400s)
install_plist "kometa" 14400 "$SCRIPT_DIR/run-kometa.sh"

echo ""
echo -e "${YELLOW}Optional:${NC} VPN failover (requires NordVPN as backup)"
echo "  To install: bash $SCRIPT_DIR/install-vpn-failover.sh"
echo ""
echo "Logs: ~/Media/logs/ and ~/Media/logs/launchd/"
echo ""
echo "To uninstall all:"
echo "  for f in $LAUNCH_DIR/$PREFIX.*.plist; do launchctl unload \"\$f\" && rm \"\$f\"; done"
echo ""
