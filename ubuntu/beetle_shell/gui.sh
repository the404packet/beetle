#!/usr/bin/env bash

set -euo pipefail

GITHUB_REPO="the404packet/beetle"

GUI_DIR=""

if [[ -d "/usr/local/bin/gui" ]]; then
    GUI_DIR="/usr/local/bin/gui"
elif [[ -d "/opt/beetle-gui" ]]; then
    GUI_DIR="/opt/beetle-gui"
elif [[ -d "$(cd "$(dirname "${BASH_SOURCE[0]}")/../gui" 2>/dev/null && pwd)" ]]; then
    GUI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../gui" 2>/dev/null && pwd)"
elif [[ -d "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../gui" 2>/dev/null && pwd)" ]]; then
    GUI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../gui" 2>/dev/null && pwd)"
fi

# ── Function: Install GUI from GitHub Release ──
install_gui_from_github() {
    echo "============================================="
    echo "       Beetle GUI Installer (GitHub)        "
    echo "============================================="
    
    # Ensure curl and unzip are available
    if ! command -v curl >/dev/null 2>&1; then
        echo "==> Installing curl..."
        apt-get update && apt-get install -y curl
    fi
    if ! command -v unzip >/dev/null 2>&1; then
        echo "==> Installing unzip..."
        apt-get update && apt-get install -y unzip
    fi

    TARGET_DIR="/opt/beetle-gui"
    TMP_ZIP="/tmp/beetle-gui.zip"

    echo "==> Fetching latest release download URL from GitHub ($GITHUB_REPO)..."
    LATEST_JSON=$(curl -s "https://api.github.com/repos/${GITHUB_REPO}/releases/latest" || true)
    DOWNLOAD_URL=$(echo "$LATEST_JSON" | grep -o 'https://[^"]*beetle-gui\.zip' | head -n 1 || true)

    if [[ -z "$DOWNLOAD_URL" ]]; then
        # Fallback to direct latest download URL
        DOWNLOAD_URL="https://github.com/${GITHUB_REPO}/releases/latest/download/beetle-gui.zip"
    fi

    echo "==> Downloading Beetle GUI from: $DOWNLOAD_URL"
    if ! curl -L -f -o "$TMP_ZIP" "$DOWNLOAD_URL"; then
        echo "❌ Failed to download Beetle GUI package from GitHub release."
        echo "Please verify release package exists at: https://github.com/${GITHUB_REPO}/releases"
        rm -f "$TMP_ZIP"
        exit 1
    fi

    echo "==> Extracting to $TARGET_DIR..."
    mkdir -p "$TARGET_DIR"
    unzip -q -o "$TMP_ZIP" -d /tmp/beetle_extracted
    
    # Check whether archive extracted as gui/ or direct contents
    if [[ -d "/tmp/beetle_extracted/gui" ]]; then
        cp -a /tmp/beetle_extracted/gui/. "$TARGET_DIR/"
    else
        cp -a /tmp/beetle_extracted/. "$TARGET_DIR/"
    fi

    rm -rf /tmp/beetle_extracted "$TMP_ZIP"
    chmod +x "$TARGET_DIR/app.py" 2>/dev/null || true
    [[ -f "$TARGET_DIR/run.sh" ]] && chmod +x "$TARGET_DIR/run.sh" 2>/dev/null || true

    GUI_DIR="$TARGET_DIR"
    echo "✅ Beetle GUI successfully installed at $GUI_DIR"
}

# ── 1. Check if GUI is installed ──
if [[ -z "$GUI_DIR" || ! -f "$GUI_DIR/app.py" ]]; then
    echo "⚠️  Beetle GUI is not installed on this system."
    read -r -p "Would you like to download and install it from GitHub release? [Y/n]: " choice
    choice=${choice:-Y}
    if [[ "$choice" =~ ^[Yy]$ ]]; then
        install_gui_from_github
    else
        echo "Aborted by user."
        exit 1
    fi
fi

# ── 2. Check if Python3 and venv are installed ──
if ! command -v python3 >/dev/null 2>&1; then
    echo "⚠️  Python3 is not installed."
    read -r -p "Install Python3 now? [Y/n]: " py_choice
    py_choice=${py_choice:-Y}
    if [[ "$py_choice" =~ ^[Yy]$ ]]; then
        echo "==> Installing Python3, python3-pip, and python3-venv..."
        apt-get update
        apt-get install -y python3 python3-pip python3-venv
    else
        echo "❌ Python3 is required to run Beetle GUI."
        exit 1
    fi
fi

# Ensure python3-venv is present (Debian/Ubuntu packages venv separately)
if ! python3 -m venv --help >/dev/null 2>&1; then
    echo "==> Installing python3-venv..."
    apt-get update
    apt-get install -y python3-venv python3-pip
fi

# ── 3. Check and install Python dependencies (requirements.txt) ──
VENV_DIR="$GUI_DIR/venv"

if [[ ! -d "$VENV_DIR" ]]; then
    echo "==> Setting up Python virtual environment in $VENV_DIR..."
    python3 -m venv "$VENV_DIR"
fi

PYTHON_BIN="$VENV_DIR/bin/python3"
PIP_BIN="$VENV_DIR/bin/pip"

# Verify required python modules
NEED_INSTALL=false
if ! "$PYTHON_BIN" -c "import fastapi, uvicorn, multipart" >/dev/null 2>&1; then
    NEED_INSTALL=true
fi

if [[ "$NEED_INSTALL" == "true" ]]; then
    if [[ -f "$GUI_DIR/requirements.txt" ]]; then
        echo "==> Installing dependencies from requirements.txt..."
        "$PIP_BIN" install --upgrade pip
        "$PIP_BIN" install -r "$GUI_DIR/requirements.txt"
    else
        echo "==> requirements.txt not found, installing fastapi, uvicorn[standard], python-multipart directly..."
        "$PIP_BIN" install fastapi "uvicorn[standard]" python-multipart
    fi
fi

# ── 4. Launch Beetle GUI ──
echo "============================================="
echo "       🚀 Starting Beetle GUI Server         "
echo "============================================="
echo "Running at: http://localhost:8000"
echo "Press Ctrl+C to stop the GUI server."
echo "---------------------------------------------"

cd "$GUI_DIR"
exec "$PYTHON_BIN" app.py
