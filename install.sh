#!/usr/bin/env bash
set -euo pipefail

# Blackwall one-line installer
# Usage: curl -fsSL https://get.blackwall.io | bash

REPO="Devaretanmay/blackwall-get"
INSTALL_DIR="/usr/local/bin"
BINARY_NAME="bw"
ASSET_PREFIX="blackwall"

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

ASSET="${ASSET_PREFIX}-${OS}-${ARCH}"
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

generate_jwt() {
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -base64 48 | tr -d '\n'
  else
    python - <<'PY'
import base64, os
print(base64.b64encode(os.urandom(48)).decode())
PY
  fi
}

write_env_file() {
  local target="$1"
  local tmp
  tmp=$(mktemp)
  {
    echo "TRUST_LICENSE_PATH=$LICENSE_PATH"
    echo "TRUST_ISSUER_KEYS=$ISSUER_KEYS"
    echo "JWT_SECRET=$(generate_jwt)"
    echo "ENCRYPTION_KEY=$(generate_jwt)"
    echo "ENCRYPTION_SALT=$(python - <<'PY'
import os
print(os.urandom(16).hex())
PY
)"
    echo "DB_REQUIRED=false"
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
else
  if ! grep -q '^JWT_SECRET=' "$ENV_FILE" 2>/dev/null; then
    info "Adding JWT_SECRET to $ENV_FILE"
    if [[ -w "$ENV_DIR" ]]; then
      printf '\nJWT_SECRET=%s\n' "$(generate_jwt)" >> "$ENV_FILE"
    else
      printf '\nJWT_SECRET=%s\n' "$(generate_jwt)" | sudo tee -a "$ENV_FILE" >/dev/null
    fi
  fi
  if ! grep -q '^ENCRYPTION_KEY=' "$ENV_FILE" 2>/dev/null; then
    info "Adding ENCRYPTION_KEY to $ENV_FILE"
    if [[ -w "$ENV_DIR" ]]; then
      printf '\nENCRYPTION_KEY=%s\n' "$(generate_jwt)" >> "$ENV_FILE"
    else
      printf '\nENCRYPTION_KEY=%s\n' "$(generate_jwt)" | sudo tee -a "$ENV_FILE" >/dev/null
    fi
  fi
  if ! grep -q '^ENCRYPTION_SALT=' "$ENV_FILE" 2>/dev/null; then
    info "Adding ENCRYPTION_SALT to $ENV_FILE"
    if [[ -w "$ENV_DIR" ]]; then
      printf '\nENCRYPTION_SALT=%s\n' "$(python - <<'PY'
import os
print(os.urandom(16).hex())
PY
)" >> "$ENV_FILE"
    else
      printf '\nENCRYPTION_SALT=%s\n' "$(python - <<'PY'
import os
print(os.urandom(16).hex())
PY
)" | sudo tee -a "$ENV_FILE" >/dev/null
    fi
  fi
  if ! grep -q '^DB_REQUIRED=' "$ENV_FILE" 2>/dev/null; then
    info "Adding DB_REQUIRED=false to $ENV_FILE"
    if [[ -w "$ENV_DIR" ]]; then
      printf '\nDB_REQUIRED=false\n' >> "$ENV_FILE"
    else
      printf '\nDB_REQUIRED=false\n' | sudo tee -a "$ENV_FILE" >/dev/null
    fi
  fi
fi

# Initialize
if command -v blackwall >/dev/null 2>&1; then
  info "Running: blackwall init"
  blackwall init || true
fi

if [[ -w "$ENV_DIR" ]]; then
  chmod 0644 "$ENV_FILE" || true
else
  sudo chmod 0644 "$ENV_FILE" || true
fi

info "Done. Run 'blackwall --help' to get started."