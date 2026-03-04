#!/usr/bin/env bash

set -euo pipefail

echo "🚀 Deploying Beetle..."

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

BEETLE_SRC="$SRC_DIR/beetle"
BEETLED_SRC="$SRC_DIR/beetled"
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
[[ -f "$BEETLED_SRC" ]]  || { echo "❌ beetled file not found"; exit 1; }
[[ -f "$SERVICE_SRC" ]]  || { echo "❌ beetled.service file not found"; exit 1; }
[[ -d "$SHELL_SRC" ]]    || { echo "❌ beetle_shell directory not found"; exit 1; }
[[ -d "$CONFIG_SRC" ]]   || { echo "❌ config directory not found"; exit 1; }

# ---------- Create beetle group if not exists ----------
if ! getent group beetle >/dev/null; then
    echo "👥 Creating beetle group"
    sudo groupadd beetle
fi

# ---------- Install beetle ----------
echo "📦 Installing beetle"
sudo install -m 755 "$BEETLE_SRC" "$DEST_DIR/beetle"

# ---------- Install beetled ----------
echo "📦 Installing beetled daemon"
sudo install -m 755 "$BEETLED_SRC" "$DEST_DIR/beetled"

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
    echo "📄 Config directory installed/updated"
else
    sudo cp -an "$CONFIG_SRC/." "$CONF_DIR/"
    echo "📄 Config installed (existing files preserved)"
fi

# ---------- Install systemd service ----------
echo "⚙️ Installing systemd service"
sudo cp "$SERVICE_SRC" "$SERVICE_DEST"
sudo chmod 644 "$SERVICE_DEST"

# ---------- Normalize line endings ----------
if command -v dos2unix >/dev/null; then
    echo "🧼 Normalizing line endings"

    sudo dos2unix "$DEST_DIR/beetle" >/dev/null 2>&1 || true
    sudo dos2unix "$DEST_DIR/beetled" >/dev/null 2>&1 || true

    sudo find "$DEST_DIR/beetle_shell" -type f -name "*.sh" \
        -exec dos2unix {} \; >/dev/null 2>&1 || true

    sudo find "$CONF_DIR" -type f \
        -exec dos2unix {} \; >/dev/null 2>&1 || true
else
    echo "⚠️  dos2unix not installed (recommended)"
fi

# ---------- Permissions ----------
echo "🔐 Setting permissions"

sudo chmod +x "$DEST_DIR/beetle"
sudo chmod +x "$DEST_DIR/beetled"

sudo find "$DEST_DIR/beetle_shell" -type f -name "*.sh" \
    -exec chmod +x {} \;

# ---------- Reload systemd ----------
echo "🔄 Reloading systemd"
sudo systemctl daemon-reload

echo "🚀 Enabling beetled service"
sudo systemctl enable beetled

echo "▶️ Starting beetled service"
sudo systemctl restart beetled

# ---------- PATH sanity ----------
command -v beetle >/dev/null || echo "⚠️  /usr/local/bin not in PATH"

echo ""
echo "✅ Deployment complete!"
echo "➡️  Run: beetle banner"
echo "➡️  Check daemon: systemctl status beetled"