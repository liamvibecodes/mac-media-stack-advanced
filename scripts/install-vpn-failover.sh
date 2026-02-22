#!/bin/bash
# Installs the VPN failover watcher (Proton <-> Nord auto-switch).
# Requires .env.nord with NordVPN WireGuard credentials.

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
LAUNCH_DIR="$HOME/Library/LaunchAgents"
PLIST="$LAUNCH_DIR/com.media-stack.vpn-failover.plist"
LOG_DIR="$HOME/Media/logs/launchd"

mkdir -p "$LOG_DIR"

if [[ ! -f "$PROJECT_DIR/.env.nord" ]]; then
    echo -e "${RED}Error:${NC} .env.nord not found."
    echo "Copy .env.nord.example to .env.nord and add your NordVPN WireGuard key."
    exit 1
fi

cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.media-stack.vpn-failover</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>$SCRIPT_DIR/vpn-failover-watch.sh</string>
    </array>
    <key>StartInterval</key>
    <integer>120</integer>
    <key>RunAtLoad</key>
    <true/>
    <key>StandardOutPath</key>
    <string>$LOG_DIR/vpn-failover.out.log</string>
    <key>StandardErrorPath</key>
    <string>$LOG_DIR/vpn-failover.err.log</string>
</dict>
</plist>
EOF

launchctl unload "$PLIST" 2>/dev/null || true
launchctl load "$PLIST"

echo -e "${GREEN}VPN failover installed.${NC} Checks every 2 minutes."
echo "Log: ~/Media/logs/vpn-failover.log"
