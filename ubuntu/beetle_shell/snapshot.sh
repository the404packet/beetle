#!/usr/bin/env bash

BASE_DIR="/var/lib/beetle"
STORE_DIR="$BASE_DIR/.snapshot_store"
BEETLE_DIR="$BASE_DIR/beetle_snapshots"
USER_DIR="$BASE_DIR/user_snapshots"
SOURCE_DIR="/etc/beetle"

ID_FILE="$BASE_DIR/.snapshot_id"
META_FILE="$BASE_DIR/.snapshot_meta"

mkdir -p "$STORE_DIR" "$BEETLE_DIR" "$USER_DIR"
touch "$ID_FILE" "$META_FILE"

# ---------- HELP ----------
show_help() {
    echo "Usage:"
    echo "  beetle snapshot capture           (user snapshot)"
    echo "  beetle snapshot capture main      (system snapshot - daemon only)"
    echo "  beetle snapshot ls"
    echo "  beetle snapshot ls user"
    echo "  beetle snapshot ls beetle"
}

# ---------- ID GENERATOR ----------
get_next_id() {
    if [[ ! -s "$ID_FILE" ]]; then
        echo 1 > "$ID_FILE"
    fi

    ID=$(cat "$ID_FILE")
    NEXT_ID=$((ID + 1))
    echo "$NEXT_ID" > "$ID_FILE"

    echo "$ID"
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

    # ---------- CREATE HASH ----------
    HASH=$(create_hash)

    if [[ -z "$HASH" ]]; then
        echo "[!] Failed to compute snapshot hash"
        exit 1
    fi

    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    SNAP_ID=$(get_next_id)

    STORE_FILE="$STORE_DIR/$HASH.tar.gz"

    # ---------- STORE SNAPSHOT (DEDUP) ----------
    if [[ ! -f "$STORE_FILE" ]]; then
        tar -czf "$STORE_FILE" -C / etc/beetle
        echo "[+] New snapshot stored"
    else
        echo "[=] Duplicate snapshot detected, reusing existing data"
    fi

    # ---------- CREATE SYMLINK ----------
    SNAP_NAME="snapshot_${SNAP_ID}_${TIMESTAMP}.tar.gz"

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

    # ---------- STORE METADATA ----------
    echo "${SNAP_ID}|${SNAP_NAME}|${TIMESTAMP}|${TYPE}" >> "$META_FILE"

    echo "[+] Snapshot created:"
    echo "    ID   : $SNAP_ID"
    echo "    Name : $SNAP_NAME"
    echo "    Type : $TYPE"
}

# ---------- LIST ----------
list_snapshots() {
    TYPE=$1

    printf "\n%-5s | %-35s | %-20s | %-10s\n" "ID" "SNAPSHOT NAME" "CREATED" "TYPE"
    printf -- "-------------------------------------------------------------------------------\n"

    while IFS="|" read -r ID NAME TIME SNAP_TYPE; do
        [[ -z "$ID" ]] && continue

        if [[ -z "$TYPE" || "$TYPE" == "$SNAP_TYPE" ]]; then
            printf "%-5s | %-35s | %-20s | %-10s\n" "$ID" "$NAME" "$TIME" "$SNAP_TYPE"
        fi
    done < "$META_FILE"

    echo ""
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