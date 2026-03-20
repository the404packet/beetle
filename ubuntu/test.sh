#!/usr/bin/env bash

set -euo pipefail

echo "🚀 Deploying Beetle (C Daemon)..."

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

BEETLE_SRC="$SRC_DIR/beetle"
BEETLED_SRC="$SRC_DIR/beetled.c"
SERVICE_SRC="$SRC_DIR/beetled.service"
SHELL_SRC="$SRC_DIR/beetle_shell"
CONFIG_SRC="$SRC_DIR/config"

DEST_DIR="/usr/local/bin"
CONF_DIR="/etc/beetle"
SERVICE_DEST="/etc/systemd/system/beetled.service"

# ---------- Pre-flight ----------
command -v sudo >/dev/null || { echo "❌ sudo required"; exit 1; }
sudo -v

[[ -f "$BEETLE_SRC" ]]   || { echo "❌ beetle file not found"; exit 1; }
[[ -f "$BEETLED_SRC" ]]  || { echo "❌ beetled.c not found"; exit 1; }
[[ -f "$SERVICE_SRC" ]]  || { echo "❌ beetled.service not found"; exit 1; }
[[ -d "$SHELL_SRC" ]]    || { echo "❌ beetle_shell directory not found"; exit 1; }
[[ -d "$CONFIG_SRC" ]]   || { echo "❌ config directory not found"; exit 1; }

# ---------- Install build tools ----------
if ! command -v gcc >/dev/null; then
    echo "📥 Installing build tools (gcc)"
    sudo apt update
    sudo apt install -y build-essential
fi

# ---------- Compile daemon ----------
echo "⚙️ Compiling beetled (C daemon)"
gcc "$BEETLED_SRC" -o beetled

# ---------- Install beetle CLI ----------
echo "📦 Installing beetle CLI"
sudo install -m 755 "$BEETLE_SRC" "$DEST_DIR/beetle"

# ---------- Install beetled daemon ----------
echo "📦 Installing beetled daemon"
sudo install -m 755 ./beetled "$DEST_DIR/beetled"

# ---------- Install beetle_shell ----------
echo "📦 Installing beetle_shell"
sudo rm -rf "$DEST_DIR/beetle_shell"
sudo cp -a "$SHELL_SRC" "$DEST_DIR/"

# ---------- Install config ----------
echo "📄 Installing config directory"
sudo mkdir -p "$CONF_DIR"

FORCE_CONFIG=false
[[ "${1:-}" == "--force-config" ]] && FORCE_CONFIG=true

if [[ "$FORCE_CONFIG" == true ]]; then
    sudo rm -rf "$CONF_DIR"
    sudo mkdir -p "$CONF_DIR"
    sudo cp -a "$CONFIG_SRC/." "$CONF_DIR/"
    echo "📄 Config installed/updated"
else
    sudo cp -an "$CONFIG_SRC/." "$CONF_DIR/"
    echo "📄 Config installed (preserved)"
fi

# ---------- Install systemd service ----------
echo "⚙️ Installing systemd service"
sudo cp "$SERVICE_SRC" "$SERVICE_DEST"
sudo chmod 644 "$SERVICE_DEST"

# ---------- Normalize line endings ----------
if command -v dos2unix >/dev/null; then
    echo "🧼 Normalizing line endings"

    sudo dos2unix "$DEST_DIR/beetle" >/dev/null 2>&1 || true

    sudo find "$DEST_DIR/beetle_shell" -type f -name "*.sh" \
        -exec dos2unix {} \; >/dev/null 2>&1 || true

    sudo find "$CONF_DIR" -type f \
        -exec dos2unix {} \; >/dev/null 2>&1 || true
fi

# ---------- Permissions ----------
echo "🔐 Setting permissions"
sudo chmod +x "$DEST_DIR/beetle"
sudo chmod +x "$DEST_DIR/beetled"

sudo find "$DEST_DIR/beetle_shell" -type f -name "*.sh" \
    -exec chmod +x {} \;

# ---------- Cleanup old socket ----------
echo "🧹 Cleaning old socket"
sudo rm -f /var/run/beetle.sock

# ---------- Stop old services ----------
echo "🛑 Stopping old beetled"
sudo systemctl stop beetled 2>/dev/null || true

# ---------- Reload systemd ----------
echo "🔄 Reloading systemd"
sudo systemctl daemon-reload

# ---------- Enable + Start ----------
echo "🚀 Enabling beetled"
sudo systemctl enable beetled

echo "▶️ Starting beetled"
sudo systemctl restart beetled

# ---------- Done ----------
echo ""
echo "✅ Deployment complete!"
echo "➡️  Run: beetle banner"
echo "➡️  Check: systemctl status beetled"