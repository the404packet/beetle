#!/usr/bin/env bash

set -euo pipefail

echo "🚀 Deploying Beetle..."

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

BEETLE_SRC="$SRC_DIR/beetle"
SHELL_SRC="$SRC_DIR/beetle_shell"
CONFIG_SRC="$SRC_DIR/config"

DEST_DIR="/usr/local/bin"
CONF_DIR="/etc/beetle"

# ---------- Pre-flight ----------
command -v sudo >/dev/null || { echo "❌ sudo required"; exit 1; }
sudo -v

[[ -f "$BEETLE_SRC" ]] || { echo "❌ beetle file not found"; exit 1; }
[[ -d "$SHELL_SRC" ]]  || { echo "❌ beetle_shell directory not found"; exit 1; }
[[ -d "$CONFIG_SRC" ]] || { echo "❌ config directory not found"; exit 1; }

# ---------- Install beetle ----------
echo "📦 Installing beetle"
sudo install -m 755 "$BEETLE_SRC" "$DEST_DIR/beetle"

# ---------- Install beetle_shell (recursive) ----------
echo "📦 Installing beetle_shell"
sudo rm -rf "$DEST_DIR/beetle_shell"
sudo cp -a "$SHELL_SRC" "$DEST_DIR/"

# ---------- Install config directory ----------
echo "📄 Installing config directory"
sudo mkdir -p "$CONF_DIR"

FORCE_CONFIG=false
[[ "${1:-}" == "--force-config" ]] && FORCE_CONFIG=true

if [[ "$FORCE_CONFIG" == true ]]; then
    sudo rm -rf "$CONF_DIR"
    sudo mkdir -p "$CONF_DIR"
    sudo cp -a "$CONFIG_SRC/." "$CONF_DIR/"
    echo "📄 Config directory installed/updated"
else
    sudo cp -an "$CONFIG_SRC/." "$CONF_DIR/"
    echo "📄 Config installed (existing files preserved)"
fi

# ---------- Normalize line endings (important for WSL) ----------
if command -v dos2unix >/dev/null; then
    echo "🧼 Normalizing line endings"

    sudo dos2unix "$DEST_DIR/beetle" >/dev/null 2>&1 || true

    sudo find "$DEST_DIR/beetle_shell" -type f -name "*.sh" \
        -exec dos2unix {} \; >/dev/null 2>&1 || true

    sudo find "$CONF_DIR" -type f \
        -exec dos2unix {} \; >/dev/null 2>&1 || true
else
    echo "⚠️  dos2unix not installed (recommended)"
fi

# ---------- Permissions ----------
echo "🔐 Setting executable permissions"

sudo chmod +x "$DEST_DIR/beetle"

sudo find "$DEST_DIR/beetle_shell" -type f -name "*.sh" \
    -exec chmod +x {} \;

# ---------- PATH sanity ----------
command -v beetle >/dev/null || echo "⚠️  /usr/local/bin not in PATH"

echo "✅ Deployment complete!"
echo "➡️  Run: beetle banner"