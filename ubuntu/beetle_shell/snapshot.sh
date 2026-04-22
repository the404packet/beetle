#!/usr/bin/env bash

BASE_DIR="/var/lib/beetle"
STORE_DIR="$BASE_DIR/.snapshot_store"
BEETLE_DIR="$BASE_DIR/beetle_snapshots"
USER_DIR="$BASE_DIR/user_snapshots"
SOURCE_DIR="/etc/beetle"

META_FILE="$BASE_DIR/.snapshot_meta"

STATE_SCRIPT="/usr/local/bin/beetle_shell/lib/state_snapshot.sh"

mkdir -p "$STORE_DIR" "$BEETLE_DIR" "$USER_DIR"
touch "$META_FILE"

# ---------- HELP ----------
show_help() {
    echo "Usage:"
    echo "  beetle snapshot capture [--name <snapshot_name>]"
    echo "  beetle snapshot capture main [--name <snapshot_name>]"
    echo "  beetle snapshot ls"
    echo "  beetle snapshot rm <id|name>"
}

# ---------- ID ----------
generate_id() {
    date +"%Y%m%d%H%M%S"
}

# ---------- CAPTURE ----------
capture_snapshot() {
    MODE=""
    CUSTOM_NAME=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            main) MODE="main"; shift ;;
            --name) CUSTOM_NAME="$2"; shift 2 ;;
            *) echo "[!] Unknown argument: $1"; exit 1 ;;
        esac
    done

    TYPE=$([[ -z "$MODE" ]] && echo "user" || echo "beetle")
    TARGET_DIR=$([[ "$TYPE" == "user" ]] && echo "$USER_DIR" || echo "$BEETLE_DIR")

    # ---------- ROOT CHECK ----------
    if [[ "$EUID" -ne 0 ]]; then
        echo "[!] Snapshot requires root"
        exit 1
    fi

    # ---------- DAEMON CHECK ----------
    if [[ "$TYPE" == "beetle" ]]; then
        BEETLED_PID=$(pgrep -x beetled)
        if [[ -z "$BEETLED_PID" || "$PPID" -ne "$BEETLED_PID" ]]; then
            echo "[!] Only beetled daemon can trigger system snapshots"
            exit 1
        fi
    fi

    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    SNAP_ID=$(generate_id)

    STORE_FILE="$STORE_DIR/${SNAP_ID}.tar.gz"

    # =====================================
    # 🔥 TEMP STATE DIR (SAFE LOCATION)
    # =====================================
    STATE_TMP="$BASE_DIR/.beetle_state"

    # Cleanup safety (runs on exit)
    trap 'rm -rf "$STATE_TMP"' EXIT

    rm -rf "$STATE_TMP"
    mkdir -p "$STATE_TMP"

    STATE_OUT="$STATE_TMP/state.json"

    # ---------- RUN STATE GENERATOR ----------
    if [[ ! -f "$STATE_SCRIPT" ]]; then
        echo "[!] State script not found: $STATE_SCRIPT"
        exit 1
    fi

    bash "$STATE_SCRIPT" \
        --concerned "$SOURCE_DIR/concerned.json" \
        --output "$STATE_OUT" || {
            echo "[!] State capture failed"
            exit 1
        }

    # =====================================
    # 📦 CREATE TAR (NO DUPLICATION)
    # =====================================
    tar -czf "$STORE_FILE" \
    -C "$SOURCE_DIR" $(ls "$SOURCE_DIR") \
    -C "$STATE_TMP" state.json

    # ---------- CLEANUP ----------
    rm -rf "$STATE_TMP"
    trap - EXIT

    # ---------- NAME ----------
    SNAP_NAME=${CUSTOM_NAME:-snapshot_${SNAP_ID}}.tar.gz

    if [[ -e "$TARGET_DIR/$SNAP_NAME" ]]; then
        echo "[!] Snapshot name already exists"
        exit 1
    fi

    # ---------- SYMLINK ----------
    ln -s "$STORE_FILE" "$TARGET_DIR/$SNAP_NAME" || {
        echo "[!] Failed to create snapshot link"
        exit 1
    }

    # ---------- META ----------
    echo "${SNAP_ID}|${SNAP_NAME}|${TIMESTAMP}|${TYPE}|NA" >> "$META_FILE"

    echo "[+] Snapshot created:"
    echo "    ID   : $SNAP_ID"
    echo "    Name : $SNAP_NAME"
    echo "    Type : $TYPE"
}

# ---------- REMOVE ----------
remove_snapshot() {
    local INPUT="$1"

    [[ -z "$INPUT" ]] && {
        echo "[!] Usage: beetle snapshot rm <id|name>"
        exit 1
    }

    MATCH=$(grep -E "^${INPUT}\|" "$META_FILE")
    [[ -z "$MATCH" ]] && MATCH=$(grep -E "\|${INPUT}\|" "$META_FILE")
    [[ -z "$MATCH" ]] && MATCH=$(grep -E "\|${INPUT}\.tar\.gz\|" "$META_FILE")

    if [[ -z "$MATCH" ]]; then
        echo "[!] No snapshot found for: $INPUT"
        exit 1
    fi

    SNAP_ID=$(echo "$MATCH"   | cut -d'|' -f1)
    SNAP_NAME=$(echo "$MATCH" | cut -d'|' -f2)
    SNAP_TYPE=$(echo "$MATCH" | cut -d'|' -f4)

    if [[ "$SNAP_TYPE" == "beetle" ]]; then
        SNAP_LINK="$BEETLE_DIR/$SNAP_NAME"

        BEETLED_PID=$(pgrep -x beetled)
        if [[ -z "$BEETLED_PID" || "$PPID" -ne "$BEETLED_PID" ]]; then
            echo "[!] Permission denied: beetle snapshots can only be removed by daemon"
            exit 1
        fi
    else
        SNAP_LINK="$USER_DIR/$SNAP_NAME"
    fi

    if [[ -L "$SNAP_LINK" ]]; then
        rm "$SNAP_LINK"
        echo "[+] Removed snapshot link"
    fi

    sed -i "/^${SNAP_ID}|/d" "$META_FILE"
    echo "[+] Removed metadata entry"
}

# ---------- LIST ----------
list_snapshots() {
    TYPE=$1

    printf "\n%-15s | %-35s | %-20s | %-10s\n" "ID" "SNAPSHOT NAME" "CREATED" "TYPE"
    printf -- "-------------------------------------------------------------------------------------------\n"

    while IFS="|" read -r ID NAME TIME SNAP_TYPE HASH; do
        [[ -z "$ID" ]] && continue

        if [[ -z "$TYPE" || "$TYPE" == "$SNAP_TYPE" ]]; then
            printf "%-15s | %-35s | %-20s | %-10s\n" "$ID" "$NAME" "$TIME" "$SNAP_TYPE"
        fi
    done < "$META_FILE"

    echo ""
}

# ---------- MAIN ----------
case "$1" in
    capture)
        shift
        capture_snapshot "$@"
        ;;
    ls)
        list_snapshots "$2"
        ;;
    rm)
        remove_snapshot "$2"
        ;;
    *)
        show_help
        ;;
esac