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
    echo "Try: sudo ./setup-license.sh"
    exit 1
fi

# Function to fetch latest release
fetch_binaries() {
    if [ -f "./blackwall-license" ]; then
        return 0
    fi

    echo "Binaries not found. Fetching latest release..."
    
    # Get latest release data
    LATEST_REL=$(curl -s "https://api.github.com/repos/$REPO/releases/latest")
    
    # Find asset URL (looking for blackwall-trial-binary-*.tar.gz)
    ASSET_URL=$(echo "$LATEST_REL" | grep "browser_download_url" | grep "blackwall-trial-binary" | cut -d '"' -f 4 | head -n 1)
    
    if [ -z "$ASSET_URL" ]; then
        echo -e "${RED}Error: Could not find release asset.${NC}"
        echo "Check if a release exists at https://github.com/$REPO/releases"
        exit 1
    fi

    echo "Downloading: $ASSET_URL"
    curl -L -o blackwall.tar.gz "$ASSET_URL"
    
    echo "Extracting..."
    tar -xzf blackwall.tar.gz --strip-components=1
    rm blackwall.tar.gz
    
    echo -e "${GREEN}Binaries downloaded.${NC}"
}

# Ensure binaries are present
fetch_binaries

# License Logic
LICENSE_TOOL="./blackwall-license"
mkdir -p "$DATA_DIR"
LICENSE_PATH="$DATA_DIR/license.json"

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
