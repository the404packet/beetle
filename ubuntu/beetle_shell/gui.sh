#!/usr/bin/env bash

set -euo pipefail

GITHUB_REPO="the404packet/beetle"
GUI_DIR=""

# ── Locate an existing GUI install ──

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || true)"

if [[ -f "/usr/local/bin/gui/app.py" ]]; then
    GUI_DIR="/usr/local/bin/gui"
elif [[ -f "/opt/beetle-gui/app.py" ]]; then
    GUI_DIR="/opt/beetle-gui"
elif [[ -n "$SCRIPT_DIR" && -f "$SCRIPT_DIR/../gui/app.py" ]]; then
    GUI_DIR="$(cd "$SCRIPT_DIR/../gui" && pwd)"
elif [[ -n "$SCRIPT_DIR" && -f "$SCRIPT_DIR/../../gui/app.py" ]]; then
    GUI_DIR="$(cd "$SCRIPT_DIR/../../gui" && pwd)"
fi

# ── Helper Function: Interactive Prompt via Beetle IPC (FD 4) ──

prompt_user() {
    local prompt_text="$1"
    local default_val="${2:-Y}"

    # If running interactively under Beetle daemon (BEETLE_INTERACTIVE=1),
    # use File Descriptor 4.
    if [[ "${BEETLE_INTERACTIVE:-0}" == "1" ]] && [ -e /dev/fd/4 ]; then

        # Output PROMPT: prefix to stdout for the Beetle CLI to intercept.
        echo "PROMPT:$prompt_text"

        # Read answer sent back by daemon into FD 4.
        local raw_ans=""

        if read -r raw_ans <&4; then
            # Strip "ANSWER:" prefix (e.g., ANSWER:y or ANSWER:n).
            local ans="${raw_ans#ANSWER:}"

            if [[ "$ans" =~ ^[Yy]$ ]]; then
                return 0
            else
                return 1
            fi
        else
            # Fallback if read fails.
            [[ "$default_val" =~ ^[Yy]$ ]] && return 0 || return 1
        fi
    else
        # Fallback for standard standalone CLI execution.
        local choice

        read -r -p "$prompt_text [$default_val]: " choice
        choice="${choice:-$default_val}"

        [[ "$choice" =~ ^[Yy]$ ]] && return 0 || return 1
    fi
}

# ── Helper: run apt-get only when root/sudo is available ──

apt_install() {
    if [[ $EUID -ne 0 ]]; then
        echo "❌ Root privileges are required to install packages: $*"
        echo "   Re-run with sudo."
        exit 1
    fi
    apt-get update
    apt-get install -y "$@"
}

# ── Function: Install GUI from GitHub Release ──

install_gui_from_github() {
    echo "============================================="
    echo "        Beetle GUI Installer (GitHub)"
    echo "============================================="

    if ! command -v curl >/dev/null 2>&1; then
        echo "==> Installing curl..."
        apt_install curl
    fi

    if ! command -v unzip >/dev/null 2>&1; then
        echo "==> Installing unzip..."
        apt_install unzip
    fi

    TARGET_DIR="/opt/beetle-gui"
    TMP_ZIP="/tmp/beetle-gui.zip"
    TMP_EXTRACT="/tmp/beetle_extracted"

    echo "==> Fetching latest release download URL from GitHub ($GITHUB_REPO)..."

    LATEST_JSON=$(curl -s "https://api.github.com/repos/${GITHUB_REPO}/releases/latest" || true)

    DOWNLOAD_URL=$(echo "$LATEST_JSON" \
        | grep -o 'https://[^"]*beetle-gui\.zip' \
        | head -n 1 || true)

    if [[ -z "$DOWNLOAD_URL" ]]; then
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

    rm -rf "$TMP_EXTRACT"
    mkdir -p "$TARGET_DIR" "$TMP_EXTRACT"

    unzip -q -o "$TMP_ZIP" -d "$TMP_EXTRACT"

    if [[ -d "$TMP_EXTRACT/gui" ]]; then
        cp -a "$TMP_EXTRACT/gui/." "$TARGET_DIR/"
    else
        cp -a "$TMP_EXTRACT/." "$TARGET_DIR/"
    fi

    rm -rf "$TMP_EXTRACT" "$TMP_ZIP"

    # A venv shipped inside the release zip was built on the CI runner and has
    # hardcoded absolute paths, so it can never work here. Always discard it.
    rm -rf "$TARGET_DIR/venv"

    chmod +x "$TARGET_DIR/app.py" 2>/dev/null || true

    [[ -f "$TARGET_DIR/run.sh" ]] && chmod +x "$TARGET_DIR/run.sh" 2>/dev/null || true

    GUI_DIR="$TARGET_DIR"

    echo "✅ Beetle GUI successfully installed at $GUI_DIR"
}

# ── 1. Check if GUI is installed ──

if [[ -z "$GUI_DIR" || ! -f "$GUI_DIR/app.py" ]]; then
    echo "⚠️ Beetle GUI is not installed on this system."

    if prompt_user "Would you like to download and install it from GitHub release?" "Y"; then
        install_gui_from_github
    else
        echo "Aborted by user."
        exit 1
    fi
fi

# ── 2. Check Python3, venv and ensurepip ──

if ! command -v python3 >/dev/null 2>&1; then
    echo "⚠️ Python3 is not installed."

    if prompt_user "Install Python3 now?" "Y"; then
        echo "==> Installing Python3, python3-pip, and python3-venv..."
        apt_install python3 python3-pip python3-venv
    else
        echo "❌ Python3 is required to run Beetle GUI."
        exit 1
    fi
fi

# `python3 -m venv --help` succeeds even when ensurepip is missing, so test
# ensurepip directly.
if ! python3 -c "import ensurepip, venv" >/dev/null 2>&1; then
    echo "==> Installing python3-venv and python3-pip..."

    PY_MINOR="$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')"

    # Try the version-specific package first (e.g. python3.10-venv), then generic.
    if [[ $EUID -ne 0 ]]; then
        echo "❌ Root privileges are required. Re-run with sudo."
        exit 1
    fi
    apt-get update
    apt-get install -y "python${PY_MINOR}-venv" python3-pip \
        || apt-get install -y python3-venv python3-pip

    if ! python3 -c "import ensurepip, venv" >/dev/null 2>&1; then
        echo "❌ Could not get python venv/ensurepip working."
        echo "   Try manually: sudo apt install python${PY_MINOR}-venv"
        exit 1
    fi
fi

# ── 3. Create (or repair) venv and install dependencies ──

VENV_DIR="$GUI_DIR/venv"
PYTHON_BIN="$VENV_DIR/bin/python3"

# Recreate the venv if it's missing, half-built, or broken
# (e.g. stale CI paths, or a previous failed creation with no pip).
if [[ ! -x "$PYTHON_BIN" ]] || ! "$PYTHON_BIN" -m pip --version >/dev/null 2>&1; then
    echo "==> (Re)creating Python virtual environment in $VENV_DIR..."
    rm -rf "$VENV_DIR"

    if ! python3 -m venv "$VENV_DIR"; then
        rm -rf "$VENV_DIR"
        echo "❌ Failed to create virtual environment."
        exit 1
    fi
fi

NEED_INSTALL=false

if ! "$PYTHON_BIN" -c "import fastapi, uvicorn, multipart" >/dev/null 2>&1; then
    NEED_INSTALL=true
fi

if [[ "$NEED_INSTALL" == "true" ]]; then
    # Always call pip via `python -m pip` so the pip script's shebang is irrelevant.
    "$PYTHON_BIN" -m pip install --upgrade pip

    if [[ -f "$GUI_DIR/requirements.txt" ]]; then
        echo "==> Installing dependencies from requirements.txt..."
        "$PYTHON_BIN" -m pip install -r "$GUI_DIR/requirements.txt"
    else
        echo "==> requirements.txt not found, installing dependencies directly..."
        "$PYTHON_BIN" -m pip install fastapi "uvicorn[standard]" python-multipart
    fi
fi

# ── 4. Launch Beetle GUI ──

echo "============================================="
echo "          🚀 Starting Beetle GUI Server"
echo "============================================="

echo "Running at: http://localhost:8000"
echo "Press Ctrl+C to stop the GUI server."
echo "---------------------------------------------"

cd "$GUI_DIR"

exec "$PYTHON_BIN" app.py