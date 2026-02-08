#!/usr/bin/env bash
set -euo pipefail

# Blackwall one-line installer
# Usage: curl -fsSL https://get.blackwall.io | bash

REPO="Devaretanmay/blackwall-get"
INSTALL_DIR="/usr/local/bin"
BINARY_NAME="blackwall"

err() { echo "[blackwall] $*" >&2; }
info() { echo "[blackwall] $*"; }

# Detect OS/arch
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

case "$ARCH" in
  x86_64|amd64) ARCH="amd64" ;;
  aarch64|arm64) ARCH="arm64" ;;
  *) err "Unsupported architecture: $ARCH"; exit 1 ;;
 esac

case "$OS" in
  linux|darwin) ;; 
  *) err "Unsupported OS: $OS"; exit 1 ;;
 esac

# Pick latest release
API_URL="https://api.github.com/repos/$REPO/releases/latest"
TAG=$(curl -fsSL "$API_URL" | grep '"tag_name"' | head -1 | sed -E 's/.*"([^"]+)".*/\1/')
if [[ -z "${TAG:-}" ]]; then
  err "Could not determine latest release tag."; exit 1
fi

ASSET="${BINARY_NAME}-${OS}-${ARCH}"
URL="https://github.com/$REPO/releases/download/$TAG/$ASSET"

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

info "Downloading $ASSET ($TAG)..."
curl -fsSL "$URL" -o "$TMP_DIR/$BINARY_NAME"

chmod +x "$TMP_DIR/$BINARY_NAME"

# Install
if [[ -w "$INSTALL_DIR" ]]; then
  mv "$TMP_DIR/$BINARY_NAME" "$INSTALL_DIR/$BINARY_NAME"
else
  info "Installing with sudo to $INSTALL_DIR..."
  sudo mv "$TMP_DIR/$BINARY_NAME" "$INSTALL_DIR/$BINARY_NAME"
fi

info "Installed: $INSTALL_DIR/$BINARY_NAME"

# Configure trust env file
ENV_DIR="/var/lib/blackwall"
ENV_FILE="$ENV_DIR/blackwall.env"
LICENSE_PATH_DEFAULT="/var/lib/blackwall/license.json"
ISSUER_KEYS_DEFAULT="/duYovG0PEc69OHjqk7D8k2oCdcEkY/gaX2LSi8pCKs="
LICENSE_PATH="${TRUST_LICENSE_PATH:-$LICENSE_PATH_DEFAULT}"
ISSUER_KEYS="${TRUST_ISSUER_KEYS:-$ISSUER_KEYS_DEFAULT}"

write_env_file() {
  local target="$1"
  local tmp
  tmp=$(mktemp)
  {
    echo "TRUST_LICENSE_PATH=$LICENSE_PATH"
    echo "TRUST_ISSUER_KEYS=$ISSUER_KEYS"
  } > "$tmp"

  if [[ -w "$ENV_DIR" ]]; then
    mkdir -p "$ENV_DIR"
    mv "$tmp" "$target"
  else
    sudo mkdir -p "$ENV_DIR"
    sudo mv "$tmp" "$target"
  fi
}

if [[ ! -f "$ENV_FILE" ]]; then
  info "Writing trust config to $ENV_FILE"
  write_env_file "$ENV_FILE"
fi

# Initialize
if command -v blackwall >/dev/null 2>&1; then
  info "Running: blackwall init"
  blackwall init || true
fi

info "Done. Run 'blackwall --help' to get started."