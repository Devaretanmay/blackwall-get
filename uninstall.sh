#!/bin/bash
set -e

# Blackwall - Uninstall / Cleanup
# Usage: sudo ./uninstall.sh

# Configuration
INSTALL_DIR="/opt/blackwall"
DATA_DIR="/var/lib/blackwall"
LOG_DIR="/var/log/blackwall"
CONFIG_DIR="/etc/blackwall"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${RED}"
echo "╔══════════════════════════════════════════════════════╗"
echo "║             Blackwall Uninstaller                    ║"
echo "╚══════════════════════════════════════════════════════╝"
echo -e "${NC}"

if [ "$EUID" -ne 0 ]; then
    echo "Error: Must run as root (sudo)"
    exit 1
fi

echo -e "${YELLOW}Stopping services...${NC}"
if [[ "$OSTYPE" == "darwin"* ]]; then
    launchctl unload "/Library/LaunchDaemons/com.blackwall.platform.plist" 2>/dev/null || true
    rm -f "/Library/LaunchDaemons/com.blackwall.platform.plist"
else
    systemctl stop blackwall 2>/dev/null || true
    systemctl disable blackwall 2>/dev/null || true
    rm -f "/etc/systemd/system/blackwall.service"
    systemctl daemon-reload
fi

echo -e "${YELLOW}Removing binaries...${NC}"
rm -rf "$INSTALL_DIR"
rm -f /usr/local/bin/bw
rm -f /usr/local/bin/bw-license

echo -e "${YELLOW}Removing configuration...${NC}"
rm -rf "$CONFIG_DIR"

echo -e "${YELLOW}Removing logs...${NC}"
rm -rf "$LOG_DIR"

read -p "Do you want to remove data (license/db) at $DATA_DIR? (y/N) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Removing data..."
    rm -rf "$DATA_DIR"
else
    echo "Data preserved."
fi

echo ""
echo -e "${GREEN}✅ Uninstallation Complete.${NC}"
