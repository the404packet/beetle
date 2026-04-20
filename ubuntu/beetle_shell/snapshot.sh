#!/usr/bin/env bash

BASE_DIR="/var/lib/beetle"
STORE_DIR="$BASE_DIR/.snapshot_store"
BEETLE_DIR="$BASE_DIR/beetle_snapshots"
USER_DIR="$BASE_DIR/user_snapshots"
SOURCE_DIR="/etc/beetle"

META_FILE="$BASE_DIR/.snapshot_meta"

mkdir -p "$STORE_DIR" "$BEETLE_DIR" "$USER_DIR"
touch "$META_FILE"

# ---------- HELP ----------
show_help() {
    echo "Usage:"
    echo "  beetle snapshot capture [--name <snapshot_name>]"
    echo "  beetle snapshot capture main [--name <snapshot_name>]"
    echo "  beetle snapshot ls"
    echo "  beetle snapshot ls user"
    echo "  beetle snapshot ls beetle"
}

# ---------- ID ----------
generate_id() {
    date +"%Y%m%d%H%M%S"
}

# ---------- HASH ----------
create_hash() {
    tar -czf - -C / etc/beetle 2>/dev/null | sha256sum | awk '{print $1}'
}

# ---------- CAPTURE ----------
capture_snapshot() {
    MODE=""
    CUSTOM_NAME=""

    # -------- ARG PARSING --------
    while [[ $# -gt 0 ]]; do
        case "$1" in
            main)
                MODE="main"
                shift
                ;;
            --name)
                CUSTOM_NAME="$2"
                shift 2
                ;;
            *)
                echo "[!] Unknown argument: $1"
                exit 1
                ;;
        esac
    done

    # TYPE
    if [[ -z "$MODE" ]]; then
        TYPE="user"
    else
        TYPE="beetle"
    fi

    # TARGET DIR
    if [[ "$TYPE" == "user" ]]; then
        TARGET_DIR="$USER_DIR"
    else
        TARGET_DIR="$BEETLE_DIR"
    fi

    # SECURITY CHECK
    if [[ "$TYPE" == "beetle" ]]; then
        if [[ "$EUID" -ne 0 ]]; then
            echo "[!] Permission denied: system snapshot requires root"
            exit 1
        fi

        BEETLED_PID=$(pgrep -x beetled)

        if [[ -z "$BEETLED_PID" || "$PPID" -ne "$BEETLED_PID" ]]; then
            echo "[!] Only beetled daemon can trigger system snapshots"
            exit 1
        fi
    fi

    # HASH
    HASH=$(create_hash)
    [[ -z "$HASH" ]] && { echo "[!] Failed to compute snapshot hash"; exit 1; }

    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    SNAP_ID=$(generate_id)

    STORE_FILE="$STORE_DIR/$HASH.tar.gz"

    # DEDUP
    if [[ ! -f "$STORE_FILE" ]]; then
        tar -czf "$STORE_FILE" -C / etc/beetle
        echo "[+] New snapshot stored"
    else
        echo "[=] Duplicate snapshot detected, reusing existing data"
    fi

    # ---------- NAME HANDLING ----------
    if [[ -n "$CUSTOM_NAME" ]]; then
        BASE_NAME="$CUSTOM_NAME"
        SNAP_NAME="${BASE_NAME}.tar.gz"

        if [[ -e "$TARGET_DIR/$SNAP_NAME" ]]; then
            echo "[!] Snapshot name '$CUSTOM_NAME' already exists. Use a different name."
            exit 1
        fi
    else
        SNAP_NAME="snapshot_${SNAP_ID}.tar.gz"
    fi

    # ---------- SYMLINK ----------
    ln -s "$STORE_FILE" "$TARGET_DIR/$SNAP_NAME" || {
        echo "[!] Failed to create snapshot link"
        exit 1
    }

    # ---------- METADATA ----------
    echo "${SNAP_ID}|${SNAP_NAME}|${TIMESTAMP}|${TYPE}|${HASH}" >> "$META_FILE"

    echo "[+] Snapshot created:"
    echo "    ID   : $SNAP_ID"
    echo "    Name : $SNAP_NAME"
    echo "    Type : $TYPE"
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
    *)
        show_help
        ;;
esac