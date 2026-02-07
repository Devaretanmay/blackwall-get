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

# Initialize
if command -v blackwall >/dev/null 2>&1; then
  info "Running: blackwall init"
  blackwall init || true
fi

info "Done. Run 'blackwall --help' to get started."