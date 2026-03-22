#!/usr/bin/env bash

BASE_DIR="/var/lib/beetle"
STORE_DIR="$BASE_DIR/.snapshot_store"
BEETLE_DIR="$BASE_DIR/beetle_snapshots"
USER_DIR="$BASE_DIR/user_snapshots"
SOURCE_DIR="/etc/beetle"

mkdir -p "$STORE_DIR" "$BEETLE_DIR" "$USER_DIR"

# ---------- HELP ----------
show_help() {
    echo "Usage:"
    echo "  beetle snapshot capture           (user snapshot)"
    echo "  beetle snapshot capture main      (system snapshot - daemon only)"
    echo "  beetle snapshot list"
    echo "  beetle snapshot list user"
    echo "  beetle snapshot list beetle"
}

# ---------- HASH ----------
create_hash() {
    tar -cf - "$SOURCE_DIR" 2>/dev/null | sha256sum | awk '{print $1}'
}

# ---------- CAPTURE ----------
capture_snapshot() {
    MODE=$1

    # ---------- DETERMINE TYPE ----------
    if [[ -z "$MODE" ]]; then
        TYPE="user"
    elif [[ "$MODE" == "main" ]]; then
        TYPE="beetle"
    else
        echo "[!] Invalid mode"
        exit 1
    fi

    # ---------- SECURITY CHECK ----------
    if [[ "$TYPE" == "beetle" ]]; then
        # Must be root
        if [[ "$EUID" -ne 0 ]]; then
            echo "[!] Permission denied: system snapshot requires root"
            exit 1
        fi

        # Optional: ensure called by beetled
        BEETLED_PID=$(pgrep -x beetled)

        if [[ -z "$BEETLED_PID" || "$PPID" -ne "$BEETLED_PID" ]]; then
            echo "[!] Only beetled daemon can trigger system snapshots"
            exit 1
        fi
    fi

    # ---------- CREATE HASH ----------
    HASH=$(tar -cf - "$SOURCE_DIR" 2>/dev/null | sha256sum | awk '{print $1}')

    if [[ -z "$HASH" ]]; then
        echo "[!] Failed to compute snapshot hash"
        exit 1
    fi

    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    STORE_FILE="$STORE_DIR/$HASH.tar.gz"

    # ---------- STORE SNAPSHOT (DEDUP) ----------
    if [[ ! -f "$STORE_FILE" ]]; then
        tar -czf "$STORE_FILE" -C / etc/beetle
        echo "[+] New snapshot stored"
    else
        echo "[=] Duplicate snapshot detected, reusing existing data"
    fi

    # ---------- CREATE SYMLINK ----------
    SNAP_NAME="snapshot_${TIMESTAMP}.tar.gz"

    if [[ "$TYPE" == "user" ]]; then
        TARGET_DIR="$USER_DIR"
    else
        TARGET_DIR="$BEETLE_DIR"
    fi

    ln -s "$STORE_FILE" "$TARGET_DIR/$SNAP_NAME"

    if [[ $? -ne 0 ]]; then
        echo "[!] Failed to create snapshot link"
        exit 1
    fi

    echo "[+] Snapshot created:"
    echo "    Name : $SNAP_NAME"
    echo "    Type : $TYPE"
}

# ---------- LIST ----------
list_snapshots() {
    TYPE=$1

    print_list() {
        DIR=$1
        LABEL=$2

        echo "---- $LABEL ----"
        for file in "$DIR"/*; do
            [[ -e "$file" ]] || continue
            NAME=$(basename "$file")
            TIME=$(stat -c %y "$file" 2>/dev/null | cut -d'.' -f1)
            echo "$NAME  |  $TIME"
        done
        echo ""
    }

    case "$TYPE" in
        user)
            print_list "$USER_DIR" "User Snapshots"
            ;;
        beetle)
            print_list "$BEETLE_DIR" "Beetle Snapshots"
            ;;
        "")
            print_list "$BEETLE_DIR" "Beetle Snapshots"
            print_list "$USER_DIR" "User Snapshots"
            ;;
        *)
            echo "Invalid type"
            ;;
    esac
}

# ---------- MAIN ----------
case "$1" in
    capture)
        capture_snapshot "$2"
        ;;
    ls)
        list_snapshots "$2"
        ;;
    *)
        show_help
        ;;
esac