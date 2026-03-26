#!/usr/bin/env bash

set -euo pipefail

echo "🚀 Deploying Beetle (C Daemon + C Client)..."

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

BEETLE_SRC="$SRC_DIR/beetle.c"
BEETLED_SRC="$SRC_DIR/beetled.c"
SERVICE_SRC="$SRC_DIR/beetled.service"
HANDLER_SRC="$SRC_DIR/beetled-handler"
SHELL_SRC="$SRC_DIR/beetle_shell"
CONFIG_SRC="$SRC_DIR/config"

DEST_DIR="/usr/local/bin"
CONF_DIR="/etc/beetle"
SERVICE_DEST="/etc/systemd/system/beetled.service"

# ---------- Pre-flight ----------
command -v sudo >/dev/null || { echo "❌ sudo required"; exit 1; }
sudo -v

[[ -f "$BEETLE_SRC" ]]   || { echo "❌ beetle.c not found"; exit 1; }
[[ -f "$BEETLED_SRC" ]]  || { echo "❌ beetled.c not found"; exit 1; }
[[ -f "$SERVICE_SRC" ]]  || { echo "❌ beetled.service not found"; exit 1; }
[[ -f "$HANDLER_SRC" ]]  || { echo "❌ beetled-handler not found"; exit 1; }
[[ -d "$SHELL_SRC" ]]    || { echo "❌ beetle_shell directory not found"; exit 1; }
[[ -d "$CONFIG_SRC" ]]   || { echo "❌ config directory not found"; exit 1; }

# ---------- Install dos2unix if missing ----------
if ! command -v dos2unix >/dev/null; then
    echo "📥 Installing dos2unix"
    sudo apt update
    sudo apt install -y dos2unix
fi

# ---------- Normalize SOURCE files ----------
echo "🧼 Converting source files to LF"

dos2unix "$BEETLE_SRC" "$BEETLED_SRC" "$SERVICE_SRC" "$HANDLER_SRC" "$0" >/dev/null 2>&1 || true

find "$SHELL_SRC" -type f -exec dos2unix {} \; >/dev/null 2>&1 || true
find "$CONFIG_SRC" -type f -exec dos2unix {} \; >/dev/null 2>&1 || true

# ---------- Install build tools ----------
if ! command -v gcc >/dev/null; then
    echo "📥 Installing build tools (gcc)"
    sudo apt install -y build-essential
fi

# ---------- Compile ----------
echo "⚙️ Compiling beetled"
gcc "$BEETLED_SRC" -o beetled

echo "⚙️ Compiling beetle"
gcc "$BEETLE_SRC" -o beetle

# ---------- Install binaries ----------
echo "📦 Installing binaries"
sudo install -m 755 ./beetle "$DEST_DIR/beetle"
sudo install -m 755 ./beetled "$DEST_DIR/beetled"
sudo install -m 755 "$HANDLER_SRC" "$DEST_DIR/beetled-handler"

# ---------- Install shell ----------
echo "📦 Installing beetle_shell"
sudo rm -rf "$DEST_DIR/beetle_shell"
sudo cp -a "$SHELL_SRC" "$DEST_DIR/"

# ---------- Install config ----------
echo "📄 Installing config"
sudo mkdir -p "$CONF_DIR"

if [[ "${1:-}" == "--force-config" ]]; then
    sudo rm -rf "$CONF_DIR"
    sudo mkdir -p "$CONF_DIR"
    sudo cp -a "$CONFIG_SRC/." "$CONF_DIR/"
    echo "📄 Config overwritten"
else
    sudo cp -an "$CONFIG_SRC/." "$CONF_DIR/" || true
    echo "📄 Config preserved"
fi

# ---------- Install systemd ----------
echo "⚙️ Installing service"
sudo cp "$SERVICE_SRC" "$SERVICE_DEST"
sudo chmod 644 "$SERVICE_DEST"

# ---------- Normalize INSTALLED files ----------
echo "🧼 Converting installed files to LF"

sudo dos2unix "$DEST_DIR/beetle" "$DEST_DIR/beetled-handler" >/dev/null 2>&1 || true

sudo find "$DEST_DIR/beetle_shell" -type f -exec dos2unix {} \; >/dev/null 2>&1 || true
sudo find "$CONF_DIR" -type f -exec dos2unix {} \; >/dev/null 2>&1 || true

# ---------- Permissions ----------
echo "🔐 Setting permissions"
sudo chmod +x "$DEST_DIR/beetle"
sudo chmod +x "$DEST_DIR/beetled"
sudo chmod +x "$DEST_DIR/beetled-handler"

sudo find "$DEST_DIR/beetle_shell" -type f -name "*.sh" -exec chmod +x {} \;

# ---------- Cleanup ----------
echo "🧹 Cleaning old socket"
sudo rm -f /var/run/beetle.sock

echo "🛑 Stopping old daemon"
sudo systemctl stop beetled 2>/dev/null || true

# ---------- Start ----------
echo "🔄 Reloading systemd"
sudo systemctl daemon-reload

echo "🚀 Enabling beetled"
sudo systemctl enable beetled

echo "▶️ Starting beetled"
sudo systemctl restart beetled

# ---------- Done ----------
echo ""
echo "✅ Deployment complete!"
echo "➡️  Try: beetle snapshot capture"
echo "➡️  Status: systemctl status beetled"