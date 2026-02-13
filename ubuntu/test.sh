#!/usr/bin/env bash

set -e

echo "🚀 Deploying Beetle..."

SRC_DIR="$(cd "$(dirname "$0")" && pwd)"

BEETLE_SRC="$SRC_DIR/beetle"
SHELL_SRC="$SRC_DIR/beetle_shell"

DEST_DIR="/usr/local/bin"

# Check sources
[[ -f "$BEETLE_SRC" ]] || { echo "❌ beetle file not found"; exit 1; }
[[ -d "$SHELL_SRC" ]] || { echo "❌ beetle_shell directory not found"; exit 1; }

echo "📦 Copying beetle (overwrite)..."
sudo cp -f "$BEETLE_SRC" "$DEST_DIR/beetle"

echo "📦 Copying beetle_shell directory (overwrite)..."
sudo rm -rf "$DEST_DIR/beetle_shell"
sudo cp -r "$SHELL_SRC" "$DEST_DIR/"

# echo "🔧 Fixing shebang for beetle..."
# sudo sed -i '1c #!/usr/bin/env bash' "$DEST_DIR/beetle"

echo "🧼 Converting to Unix format..."
sudo dos2unix "$DEST_DIR/beetle" 2>/dev/null || true
sudo find "$DEST_DIR/beetle_shell" -type f -name "*.sh" -exec dos2unix {} \; 2>/dev/null || true

echo "🔐 Setting executable permissions..."
sudo chmod +x "$DEST_DIR/beetle"
sudo find "$DEST_DIR/beetle_shell" -type f -name "*.sh" -exec chmod +x {} \;

echo "✅ Deployment complete!"
echo "Run: beetle banner"
