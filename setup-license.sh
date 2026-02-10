#!/bin/bash
set -e

# Blackwall - Step 1: License Setup
# Usage: sudo ./setup-license.sh

# Configuration
DATA_DIR="/var/lib/blackwall"
LICENSE_TOOL="./blackwall-license"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo "🔑 Blackwall License Setup"
echo "=========================="

if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Error: Must run as root (sudo)${NC}"
    exit 1
fi

# Ensure binary exists
if [ ! -f "$LICENSE_TOOL" ]; then
    echo -e "${RED}Error: $LICENSE_TOOL not found in current directory.${NC}"
    echo "Please run this script from the extracted release folder."
    exit 1
fi

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
# In production, this might ask for a key. For now, we generate a trial/local license as per previous logic.
"$LICENSE_TOOL" init \
    --org "local-user" \
    --type "trial" \
    --duration "8760h" \
    --features "full" \
    --out "$LICENSE_PATH"

chmod 644 "$LICENSE_PATH"
echo -e "${GREEN}Success! License saved to: $LICENSE_PATH${NC}"
echo "Now run: sudo ./install-app.sh"
