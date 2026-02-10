#!/bin/bash
set -e

# Blackwall - Step 2: App Installation
# Usage: sudo ./install-app.sh

# Configuration
INSTALL_DIR="/opt/blackwall"
DATA_DIR="/var/lib/blackwall"
LOG_DIR="/var/log/blackwall"
CONFIG_DIR="/etc/blackwall"
LICENSE_PATH="$DATA_DIR/license.json"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo "🚀 Blackwall Application Installer"
echo "=================================="

if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Error: Must run as root (sudo)${NC}"
    exit 1
fi

# 1. Check License
if [ ! -f "$LICENSE_PATH" ]; then
    echo -e "${RED}Error: License not found at $LICENSE_PATH${NC}"
    echo "Please run './setup-license.sh' first."
    exit 1
fi

# 2. Install Binaries
echo "Installing binaries..."
mkdir -p "$INSTALL_DIR" "$LOG_DIR" "$CONFIG_DIR"

# Copy binaries from current dir
BINARIES=("blackwall" "blackwall-platform" "blackwall-license" "bw")
for bin in "${BINARIES[@]}"; do
    if [ -f "./$bin" ]; then
        cp "./$bin" "$INSTALL_DIR/"
        chmod +x "$INSTALL_DIR/$bin"
    else
        echo -e "${RED}Warning: Binary ./$bin not found. Skipping.${NC}"
    fi
done

# 3. Configure Env
echo "Configuring environment..."
cat > "$CONFIG_DIR/blackwall.env" << EOF
BLACKWALL_LICENSE_PATH=$LICENSE_PATH
BLACKWALL_DATA_DIR=$DATA_DIR
BLACKWALL_LOG_DIR=$LOG_DIR
LOG_LEVEL=info
EOF
chmod 644 "$CONFIG_DIR/blackwall.env"

# 4. Service Installation (Systemd/Launchd detection)
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS Launchd
    PLIST="/Library/LaunchDaemons/com.blackwall.platform.plist"
    echo "Installing Launchd service to $PLIST..."
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
    echo -e "${GREEN}Service started (macOS).${NC}"

else
    # Linux Systemd
    SERVICE_FILE="/etc/systemd/system/blackwall.service"
    echo "Installing Systemd service to $SERVICE_FILE..."
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
    echo -e "${GREEN}Service started (Linux).${NC}"
fi

# 5. Global Symlinks
ln -sf "$INSTALL_DIR/bw" /usr/local/bin/bw 2>/dev/null || echo "Could not link 'bw' to path (non-critical)"

echo ""
echo -e "${GREEN}Installation Complete!${NC}"
echo "Check status with: systemctl status blackwall (Linux) or launchctl list | grep blackwall (macOS)"
