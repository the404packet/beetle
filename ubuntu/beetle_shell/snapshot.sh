#!/usr/bin/env bash

# ==============================================================================
# Beetle Snapshot Manager — Content-Addressed Storage (CAS)
#
# Storage Layout:
#   /var/lib/beetle/
#   ├── .objects/         ← Shared object store (files stored by SHA256 hash)
#   │     └── ab/cdef..   ← Deduplicated content
#   ├── .manifests/       ← One tiny JSON per snapshot (SNAP_ID.json)
#   │     └── 20260906120000.json
#   ├── beetle_snapshots/ ← Symlinks (auto, daemon-only). Name = user-visible label
#   └── user_snapshots/   ← Symlinks (user-created). Name = user-visible label
# ==============================================================================

BASE_DIR="/var/lib/beetle"
OBJECT_DIR="$BASE_DIR/.objects"
MANIFEST_DIR="$BASE_DIR/.manifests"
BEETLE_DIR="$BASE_DIR/beetle_snapshots"
USER_DIR="$BASE_DIR/user_snapshots"
SOURCE_DIR="/etc/beetle"
META_FILE="$BASE_DIR/.snapshot_meta"
STATE_SCRIPT="/usr/local/bin/beetle_shell/lib/state_snapshot.sh"

mkdir -p "$OBJECT_DIR" "$MANIFEST_DIR" "$BEETLE_DIR" "$USER_DIR"
touch "$META_FILE"

# ---------- HELP ----------
show_help() {
    echo "Usage:"
    echo "  beetle snapshot capture [--name <snapshot_name>]"
    echo "  beetle snapshot capture main [--name <snapshot_name>]"
    echo "  beetle snapshot ls [beetle|user]"
    echo "  beetle snapshot rm <id|name>"
    echo "  beetle snapshot size"
}

# ---------- ID ----------
generate_id() {
    date +"%Y%m%d%H%M%S"
}

# ---------- STORE OBJECT ----------
# Stores a file in the object store by its SHA256 hash.
# Returns the hash. Skips storing if already exists (dedup).
store_object() {
    local file="$1"
    local hash
    hash=$(sha256sum "$file" | cut -d' ' -f1)
    local prefix="${hash:0:2}"
    local obj_path="$OBJECT_DIR/$prefix/$hash"

    mkdir -p "$OBJECT_DIR/$prefix"

    if [[ ! -f "$obj_path" ]]; then
        cp "$file" "$obj_path"
        chmod 600 "$obj_path"
    fi

    echo "$hash"
}

# ---------- CAPTURE ----------
capture_snapshot() {
    MODE=""
    CUSTOM_NAME=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            main)   MODE="main"; shift ;;
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
        BEETLED_PID=$(pgrep -x beetled | head -n1)
        ANCESTOR_PID="$$"
        FOUND=false
        while [[ "$ANCESTOR_PID" -gt 1 ]]; do
            ANCESTOR_PID=$(awk '{print $4}' /proc/$ANCESTOR_PID/stat 2>/dev/null)
            [[ "$ANCESTOR_PID" == "$BEETLED_PID" ]] && { FOUND=true; break; }
        done
        if [[ "$FOUND" != true ]]; then
            echo "[!] Only beetled daemon can trigger system snapshots"
            exit 1
        fi
    fi

    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    SNAP_ID=$(generate_id)

    # =====================================
    # GENERATE state.json
    # =====================================
    STATE_TMP="$BASE_DIR/.beetle_state_$$"
    trap 'rm -rf "$STATE_TMP"' EXIT
    mkdir -p "$STATE_TMP"
    STATE_OUT="$STATE_TMP/state.json"

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
    # BUILD MANIFEST — store each file as object
    # =====================================
    MANIFEST_FILE="$MANIFEST_DIR/${SNAP_ID}.json"

    {
        echo "{"
        echo "  \"snapshot_id\": \"$SNAP_ID\","
        echo "  \"timestamp\": \"$TIMESTAMP\","
        echo "  \"type\": \"$TYPE\","
        echo "  \"files\": {"

        FIRST=true

        # Store all files from /etc/beetle
        while IFS= read -r -d '' file; do
            rel="${file#$SOURCE_DIR/}"
            hash=$(store_object "$file")
            if [[ "$FIRST" == true ]]; then
                FIRST=false
            else
                echo ","
            fi
            printf '    "%s": "%s"' "$rel" "$hash"
        done < <(find "$SOURCE_DIR" -type f -print0)

        # Store state.json
        if [[ -f "$STATE_OUT" ]]; then
            hash=$(store_object "$STATE_OUT")
            if [[ "$FIRST" == true ]]; then
                FIRST=false
            else
                echo ","
            fi
            printf '    "__state__": "%s"' "$hash"
        fi

        echo ""
        echo "  }"
        echo "}"
    } > "$MANIFEST_FILE"

    chmod 600 "$MANIFEST_FILE"

    rm -rf "$STATE_TMP"
    trap - EXIT

    # =====================================
    # CREATE SYMLINK in user/beetle dir
    # User-visible name = custom name OR default snapshot_<id>
    # Internal manifest always uses SNAP_ID
    # =====================================
    SNAP_LABEL="${CUSTOM_NAME:-snapshot_${SNAP_ID}}"

    if [[ -e "$TARGET_DIR/$SNAP_LABEL" ]]; then
        echo "[!] Snapshot name already exists: $SNAP_LABEL"
        exit 1
    fi

    ln -s "$MANIFEST_FILE" "$TARGET_DIR/$SNAP_LABEL" || {
        echo "[!] Failed to create snapshot link"
        exit 1
    }

    # ---------- META ----------
    echo "${SNAP_ID}|${SNAP_LABEL}|${TIMESTAMP}|${TYPE}" >> "$META_FILE"

    echo "[+] Snapshot created:"
    echo "    ID   : $SNAP_ID"
    echo "    Name : $SNAP_LABEL"
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

    if [[ -z "$MATCH" ]]; then
        echo "[!] No snapshot found for: $INPUT"
        exit 1
    fi

    SNAP_ID=$(echo "$MATCH"    | cut -d'|' -f1)
    SNAP_LABEL=$(echo "$MATCH" | cut -d'|' -f2)
    SNAP_TYPE=$(echo "$MATCH"  | cut -d'|' -f4)

    if [[ "$SNAP_TYPE" == "beetle" ]]; then
        SNAP_LINK="$BEETLE_DIR/$SNAP_LABEL"

        BEETLED_PID=$(pgrep -x beetled)
        if [[ -z "$BEETLED_PID" || "$PPID" -ne "$BEETLED_PID" ]]; then
            echo "[!] Permission denied: beetle snapshots can only be removed by daemon"
            exit 1
        fi
    else
        SNAP_LINK="$USER_DIR/$SNAP_LABEL"
    fi

    # Remove symlink
    if [[ -L "$SNAP_LINK" ]]; then
        rm "$SNAP_LINK"
        echo "[+] Removed snapshot link: $SNAP_LABEL"
    fi

    # Remove manifest if no other symlink references this SNAP_ID
    MANIFEST_FILE="$MANIFEST_DIR/${SNAP_ID}.json"
    REFS=$(find "$BEETLE_DIR" "$USER_DIR" -type l | while read -r link; do
        target=$(readlink "$link")
        [[ "$target" == "$MANIFEST_FILE" ]] && echo "$link"
    done | wc -l)

    if [[ "$REFS" -eq 0 && -f "$MANIFEST_FILE" ]]; then
        # Also check if any objects become orphaned
        rm -f "$MANIFEST_FILE"
        echo "[+] Removed manifest: ${SNAP_ID}.json"
        _gc_objects
    fi

    sed -i "/^${SNAP_ID}|/d" "$META_FILE"
    echo "[+] Removed metadata entry"
}

# ---------- GARBAGE COLLECT OBJECTS ----------
# Remove objects not referenced by any remaining manifest
_gc_objects() {
    echo "[*] Running object garbage collection..."

    # Collect all hashes referenced by active manifests
    declare -A active_hashes
    while IFS= read -r -d '' manifest; do
        while IFS= read -r hash; do
            active_hashes["$hash"]=1
        done < <(python3 -c "
import json, sys
data = json.load(open('$manifest'))
for h in data.get('files', {}).values():
    print(h)
" 2>/dev/null)
    done < <(find "$MANIFEST_DIR" -type f -name "*.json" -print0)

    # Remove any object not in active_hashes
    removed=0
    while IFS= read -r -d '' obj; do
        hash=$(basename "$obj")
        if [[ -z "${active_hashes[$hash]+_}" ]]; then
            rm -f "$obj"
            removed=$((removed + 1))
        fi
    done < <(find "$OBJECT_DIR" -type f -print0)

    echo "[+] Garbage collection complete. Removed $removed unused objects."
}

# ---------- LIST ----------
list_snapshots() {
    local FILTER="${1:-}"

    printf "\n%-15s | %-35s | %-20s | %-10s\n" "ID" "SNAPSHOT NAME" "CREATED" "TYPE"
    printf -- "-------------------------------------------------------------------------------------------\n"

    while IFS="|" read -r ID LABEL TIME SNAP_TYPE; do
        [[ -z "$ID" ]] && continue
        if [[ -z "$FILTER" || "$FILTER" == "$SNAP_TYPE" ]]; then
            printf "%-15s | %-35s | %-20s | %-10s\n" "$ID" "$LABEL" "$TIME" "$SNAP_TYPE"
        fi
    done < "$META_FILE"

    echo ""
}

# ---------- SIZE REPORT ----------
show_size() {
    total_objects=$(find "$OBJECT_DIR" -type f | wc -l)
    total_manifests=$(find "$MANIFEST_DIR" -type f -name "*.json" | wc -l)
    obj_size=$(du -sh "$OBJECT_DIR" 2>/dev/null | cut -f1)
    manifest_size=$(du -sh "$MANIFEST_DIR" 2>/dev/null | cut -f1)

    echo ""
    echo "Snapshot Storage Usage:"
    echo "  Object Store  : $obj_size  ($total_objects unique file objects)"
    echo "  Manifests     : $manifest_size  ($total_manifests snapshots)"
    echo ""
}

# ---------- MAIN ----------
case "${1:-}" in
    capture) shift; capture_snapshot "$@" ;;
    ls)      list_snapshots "${2:-}" ;;
    rm)      remove_snapshot "${2:-}" ;;
    size)    show_size ;;
    gc)      _gc_objects ;;
    *)       show_help ;;
esac