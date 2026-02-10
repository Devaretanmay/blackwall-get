#!/bin/bash
set -e

# Blackwall - Step 2: App Installation
# Usage: curl ... | sudo bash

# Configuration
INSTALL_DIR="/opt/blackwall"
DATA_DIR="/var/lib/blackwall"
LOG_DIR="/var/log/blackwall"
CONFIG_DIR="/etc/blackwall"
LICENSE_PATH="$DATA_DIR/license.json"
REPO="Devaretanmay/blackwall-get"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

clear
echo -e "${BLUE}"
echo "╔══════════════════════════════════════════════════════╗"
echo "║          Blackwall Application Installer             ║"
echo "╚══════════════════════════════════════════════════════╝"
echo -e "${NC}"

if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Error: Must run as root (sudo)${NC}"
    exit 1
fi

if [ ! -f "$LICENSE_PATH" ]; then
    echo -e "${RED}Error: License not found at $LICENSE_PATH${NC}"
    echo "Please run 'setup-license.sh' first."
    exit 1
fi

WORK_DIR=$(mktemp -d)
cleanup() {
    rm -rf "$WORK_DIR"
}
trap cleanup EXIT

# Fetch Binaries
echo "Fetching latest binaries..."
# Use the specific tag v2.1.0-claw-test
LATEST_REL=$(curl -s "https://api.github.com/repos/$REPO/releases/tags/v2.1.0-claw-test")
ASSET_URL=$(echo "$LATEST_REL" | grep "browser_download_url" | grep "blackwall-trial-binary" | cut -d '"' -f 4 | head -n 1)

if [ -z "$ASSET_URL" ]; then echo -e "${RED}Error: Release not found.${NC}"; exit 1; fi

curl -L -s -o "$WORK_DIR/blackwall.tar.gz" "$ASSET_URL"
tar -xzf "$WORK_DIR/blackwall.tar.gz" -C "$WORK_DIR" --strip-components=1

echo "Installing to $INSTALL_DIR..."
mkdir -p "$INSTALL_DIR" "$LOG_DIR" "$CONFIG_DIR"

# Install Files
BINARIES=("blackwall" "blackwall-platform" "blackwall-license" "bw-cli")
for bin in "${BINARIES[@]}"; do
    if [ -f "$WORK_DIR/$bin" ]; then
        cp "$WORK_DIR/$bin" "$INSTALL_DIR/"
        chmod +x "$INSTALL_DIR/$bin"
    fi
done

# Config
cat > "$CONFIG_DIR/blackwall.env" << EOF
BLACKWALL_LICENSE_PATH=$LICENSE_PATH
BLACKWALL_DATA_DIR=$DATA_DIR
BLACKWALL_LOG_DIR=$LOG_DIR
LOG_LEVEL=info
DB_REQUIRED=false
EOF
chmod 644 "$CONFIG_DIR/blackwall.env"

# Service
if [[ "$OSTYPE" == "darwin"* ]]; then
    PLIST="/Library/LaunchDaemons/com.blackwall.platform.plist"
    cat > "$PLIST" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.blackwall.platform</string>
    <key>ProgramArguments</key>
    <array>
        <string>$INSTALL_DIR/blackwall-platform</string>
    </array>
    <key>EnvironmentVariables</key>
    <dict>
        <key>BLACKWALL_LICENSE_PATH</key>
        <string>$LICENSE_PATH</string>
    </dict>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>$LOG_DIR/blackwall.log</string>
    <key>StandardErrorPath</key>
    <string>$LOG_DIR/blackwall-error.log</string>
</dict>
</plist>
EOF
    launchctl unload "$PLIST" 2>/dev/null || true
    launchctl load "$PLIST"
else
    SERVICE_FILE="/etc/systemd/system/blackwall.service"
    cat > "$SERVICE_FILE" << EOF
[Unit]
Description=Blackwall Platform
After=network.target

[Service]
Type=exec
ExecStart=$INSTALL_DIR/blackwall-platform
Restart=always
EnvironmentFile=$CONFIG_DIR/blackwall.env
WorkingDirectory=$DATA_DIR

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable blackwall
    systemctl restart blackwall
fi

# Symlinks
echo "Creating symlinks..."
# Link the main CLI binary (named 'blackwall' or 'bw-cli') to 'bw'
if [ -f "$INSTALL_DIR/bw-cli" ]; then
    ln -sf "$INSTALL_DIR/bw-cli" /usr/local/bin/bw
    chmod +x /usr/local/bin/bw
    echo "Linked 'bw' -> '$INSTALL_DIR/bw-cli'"
elif [ -f "$INSTALL_DIR/blackwall" ]; then
    ln -sf "$INSTALL_DIR/blackwall" /usr/local/bin/bw
    chmod +x /usr/local/bin/bw
    echo "Linked 'bw' -> '$INSTALL_DIR/blackwall'"
elif [ -f "$INSTALL_DIR/bw" ]; then
    ln -sf "$INSTALL_DIR/bw" /usr/local/bin/bw
    chmod +x /usr/local/bin/bw
    echo "Linked 'bw' -> '$INSTALL_DIR/bw'"
else
    echo -e "${RED}Warning: CLI binary not found. 'bw' command may not work.${NC}"
fi

ln -sf "$INSTALL_DIR/blackwall-license" /usr/local/bin/bw-license 2>/dev/null || true

# Summary Box
echo ""
echo -e "${GREEN}✅ Installation Complete!${NC}"
echo ""
echo -e "${CYAN}"
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                   Blackwall Command Center                     ║"
echo "╠════════════════════════════════════════════════════════════════╣"
echo "║                                                                ║"
echo "║  bw scan .               Scan the current directory            ║"
echo "║  bw report               Generate compliance report            ║"
echo "║  bw-license status       Check license validity                ║"
echo "║                                                                ║"
echo "║  Service Status:                                               ║"
echo "║  systemctl status blackwall                                    ║"
echo "║                                                                ║"
echo "║  Logs:                                                         ║"
echo "║  tail -f /var/log/blackwall/blackwall.log                      ║"
echo "║                                                                ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"
