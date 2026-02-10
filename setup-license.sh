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
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

clear
echo -e "${BLUE}"
echo "╔══════════════════════════════════════════════════════╗"
echo "║             Blackwall License Setup                  ║"
echo "╚══════════════════════════════════════════════════════╝"
echo -e "${NC}"

if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Error: Must run as root (sudo)${NC}"
    exit 1
fi

# Interactive Prompts
echo -e "${YELLOW}Please enter your license details:${NC}"
read -p "  Organization Name (e.g., Acme Corp): " ORG_NAME
read -p "  License Duration (in days, e.g., 30): " DAYS

if [ -z "$ORG_NAME" ]; then ORG_NAME="local-user"; fi
if [ -z "$DAYS" ]; then DAYS="30"; fi

# Convert days to hours for the CLI tool
HOURS=$(($DAYS * 24))

echo ""
echo -e "${CYAN}Preparing license for:${NC} $ORG_NAME ($DAYS days / ${HOURS}h)"
echo ""

# Create a temp dir for extraction
WORK_DIR=$(mktemp -d)
cleanup() {
    rm -rf "$WORK_DIR"
}
trap cleanup EXIT

# Function to fetch latest release
fetch_binaries() {
    echo "Fetching latest release..."
    # Use the specific tag v2.1.2-claw-test-linux-amd64
    LATEST_REL=$(curl -s "https://api.github.com/repos/$REPO/releases/tags/v2.1.2-claw-test-linux-amd64")
    ASSET_URL=$(echo "$LATEST_REL" | grep "browser_download_url" | grep "blackwall-trial-binary" | cut -d '"' -f 4 | head -n 1)
    
    if [ -z "$ASSET_URL" ]; then
        echo -e "${RED}Error: Could not find release asset.${NC}"
        exit 1
    fi

    echo "Downloading tool..."
    curl -L -s -o "$WORK_DIR/blackwall.tar.gz" "$ASSET_URL"
    tar -xzf "$WORK_DIR/blackwall.tar.gz" -C "$WORK_DIR" --strip-components=1
}

fetch_binaries

# License Logic
LICENSE_TOOL="$WORK_DIR/blackwall-license"
mkdir -p "$DATA_DIR"
LICENSE_PATH="$DATA_DIR/license.json"

if [ ! -f "$LICENSE_TOOL" ]; then
    echo -e "${RED}Error: Binary not found.${NC}"
    exit 1
fi

if [ -f "$LICENSE_PATH" ]; then
    echo -e "${YELLOW}Existing license found. Backing up...${NC}"
    mv "$LICENSE_PATH" "$LICENSE_PATH.bak.$(date +%s)"
fi

echo "Generating license..."
"$LICENSE_TOOL" init \
    --org "$ORG_NAME" \
    --type "trial" \
    --duration "${HOURS}h" \
    --features "full" \
    --out "$LICENSE_PATH"

chmod 644 "$LICENSE_PATH"

echo ""
echo -e "${GREEN}✅ Success! License created at: $LICENSE_PATH${NC}"
echo -e "   Org: $ORG_NAME | Valid: $DAYS Days"
echo ""
echo -e "${CYAN}Next Step:${NC} Run the app installer."
