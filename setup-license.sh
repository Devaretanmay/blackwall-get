#!/bin/bash
set -e

# Blackwall - Step 1: License Setup
# Usage: curl ... | sudo bash

# Configuration
DATA_DIR="/var/lib/blackwall"
REPO="Devaretanmay/blackwall-get"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔑 Blackwall License Setup${NC}"
echo "=========================="

if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Error: Must run as root (sudo)${NC}"
    exit 1
fi

# Create a temp dir for extraction to avoid conflicts
WORK_DIR=$(mktemp -d)
cleanup() {
    rm -rf "$WORK_DIR"
}
trap cleanup EXIT

# Function to fetch latest release
fetch_binaries() {
    echo "Fetching latest release..."
    
    # Get latest release data
    LATEST_REL=$(curl -s "https://api.github.com/repos/$REPO/releases/latest")
    
    # Find asset URL
    ASSET_URL=$(echo "$LATEST_REL" | grep "browser_download_url" | grep "blackwall-trial-binary" | cut -d '"' -f 4 | head -n 1)
    
    if [ -z "$ASSET_URL" ]; then
        echo -e "${RED}Error: Could not find release asset.${NC}"
        exit 1
    fi

    echo "Downloading to temp: $ASSET_URL"
    curl -L -o "$WORK_DIR/blackwall.tar.gz" "$ASSET_URL"
    
    echo "Extracting..."
    tar -xzf "$WORK_DIR/blackwall.tar.gz" -C "$WORK_DIR" --strip-components=1
}

# Fetch binaries into temp dir
fetch_binaries

# License Logic
LICENSE_TOOL="$WORK_DIR/blackwall-license"
mkdir -p "$DATA_DIR"
LICENSE_PATH="$DATA_DIR/license.json"

if [ ! -f "$LICENSE_TOOL" ]; then
    echo -e "${RED}Error: Extracted binary $LICENSE_TOOL not found.${NC}"
    exit 1
fi

if [ -f "$LICENSE_PATH" ]; then
    echo "Found existing license at $LICENSE_PATH"
    if "$LICENSE_TOOL" status --license "$LICENSE_PATH" >/dev/null 2>&1; then
        echo -e "${GREEN}Existing license is valid.${NC}"
        exit 0
    else
        echo "Existing license is invalid. Backing up and creating new..."
        mv "$LICENSE_PATH" "$LICENSE_PATH.bak.$(date +%s)"
    fi
fi

echo "Generating new license..."
"$LICENSE_TOOL" init \
    --org "local-user" \
    --type "trial" \
    --duration "8760h" \
    --features "full" \
    --out "$LICENSE_PATH"

chmod 644 "$LICENSE_PATH"
echo -e "${GREEN}Success! License saved to: $LICENSE_PATH${NC}"
echo "Now run Step 2: sudo ./install-app.sh"
