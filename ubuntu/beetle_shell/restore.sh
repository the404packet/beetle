#!/usr/bin/env bash

SNAPSHOT_FILE=""
BASE_DIR="/var/lib/beetle"
META_FILE="$BASE_DIR/.snapshot_meta"
OBJECT_DIR="$BASE_DIR/.objects"
MANIFEST_DIR="$BASE_DIR/.manifests"
RESTORE_TMP="$BASE_DIR/.restore_tmp"
ETC_BEETLE="/etc/beetle"

# Resolve bundled jq
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JQ="$SELF_DIR/lib/bin/jq"
[[ -x "$JQ" ]] || JQ="$(command -v jq)"
[[ -x "$JQ" ]] || { echo "[!] jq not found (bundled or system)"; exit 1; }

# ---------- ROOT CHECK ----------
if [[ "$EUID" -ne 0 ]]; then
    echo "[!] Must be run as root"
    exit 1
fi

# ---------- ARGS ----------
while [[ $# -gt 0 ]]; do
    case "$1" in
        --snapshot) SNAPSHOT_FILE="$2"; shift 2 ;;
        *) SNAPSHOT_FILE="$1"; shift ;;
    esac
done

# ---------- RESOLVE SNAPSHOT ----------
if [[ -z "$SNAPSHOT_FILE" || "$SNAPSHOT_FILE" == "latest" ]]; then
    MATCH=$(tail -n1 "$META_FILE")
    if [[ -z "$MATCH" ]]; then
        echo "[!] No snapshots found"
        exit 1
    fi
    echo "[*] Restoring latest snapshot"
else
    MATCH=$(grep -E "^${SNAPSHOT_FILE}\|" "$META_FILE")
    [[ -z "$MATCH" ]] && MATCH=$(grep -E "\|${SNAPSHOT_FILE}\|" "$META_FILE")

    if [[ -z "$MATCH" ]]; then
        echo "[!] No snapshot found for: $SNAPSHOT_FILE"
        exit 1
    fi
fi

SNAP_ID=$(echo "$MATCH"    | cut -d'|' -f1)
SNAP_LABEL=$(echo "$MATCH" | cut -d'|' -f2)
SNAP_TYPE=$(echo "$MATCH"  | cut -d'|' -f4)

if [[ "$SNAP_TYPE" == "beetle" ]]; then
    SNAP_LINK="$BASE_DIR/beetle_snapshots/$SNAP_LABEL"
else
    SNAP_LINK="$BASE_DIR/user_snapshots/$SNAP_LABEL"
fi

if [[ ! -L "$SNAP_LINK" ]]; then
    echo "[!] Snapshot link not found: $SNAP_LINK"
    exit 1
fi

# Resolve manifest from symlink
MANIFEST_FILE=$(readlink -f "$SNAP_LINK")
if [[ ! -f "$MANIFEST_FILE" ]]; then
    echo "[!] Snapshot manifest not found: $MANIFEST_FILE"
    exit 1
fi

echo "[*] Snapshot : $SNAP_LABEL"
echo "[*] Manifest : $MANIFEST_FILE"

# ---------- PRE-RESTORE SNAPSHOT ----------
if [[ "${SKIP_SNAPSHOT:-false}" == "true" ]]; then
    echo "[*] Skipping pre-restore safety snapshot (test runner mode)"
else
    echo "[*] Capturing pre-restore safety snapshot..."
    SNAP_RESPONSE=$(beetle snapshot capture main 2>&1)
    if echo "$SNAP_RESPONSE" | grep -q "\[+\] Snapshot created"; then
        echo "[+] Safety snapshot captured"
    else
        echo "[!] Safety snapshot failed — aborting"
        echo "$SNAP_RESPONSE"
        exit 1
    fi
fi

# ---------- RESTORE /etc/beetle FILES FROM OBJECT STORE ----------
trap 'rm -rf "$RESTORE_TMP"' EXIT
rm -rf "$RESTORE_TMP"
mkdir -p "$RESTORE_TMP"

echo "[*] Restoring /etc/beetle files from object store..."

# Iterate over all files in manifest, skipping __state__
while IFS= read -r rel_path; do
    [[ -z "$rel_path" ]] && continue
    [[ "$rel_path" == "__state__" ]] && continue

    file_hash=$("$JQ" -r --arg k "$rel_path" '.files[$k]' "$MANIFEST_FILE" 2>/dev/null)
    [[ -z "$file_hash" || "$file_hash" == "null" ]] && continue

    prefix="${file_hash:0:2}"
    obj_path="$OBJECT_DIR/$prefix/$file_hash"

    if [[ ! -f "$obj_path" ]]; then
        echo "    [!] Missing object for $rel_path ($file_hash)"
        continue
    fi

    dest="$ETC_BEETLE/$rel_path"
    mkdir -p "$(dirname "$dest")"
    cp -p "$obj_path" "$dest"
    echo "    [+] Restored: $rel_path"
done < <("$JQ" -r '.files | keys[]' "$MANIFEST_FILE" 2>/dev/null)

# Extract state.json
state_hash=$("$JQ" -r '.files.__state__ // empty' "$MANIFEST_FILE" 2>/dev/null)
if [[ -n "$state_hash" && "$state_hash" != "null" ]]; then
    prefix="${state_hash:0:2}"
    obj_path="$OBJECT_DIR/$prefix/$state_hash"
    if [[ -f "$obj_path" ]]; then
        cp -p "$obj_path" "$RESTORE_TMP/state.json"
        echo "    [+] Loaded state.json from object store"
    else
        echo "    [!] state.json object missing"
    fi
fi

# ---------- LOAD STATE ----------
STATE_FILE="$RESTORE_TMP/state.json"
if [[ ! -f "$STATE_FILE" ]]; then
    echo "[!] state.json not found in object store for this snapshot"
    exit 1
fi

# ============================================================
# APPLY STATE — pure bash + jq
# ============================================================

# -------- PACKAGES --------
pkg_count=$("$JQ" '.packages | length' "$STATE_FILE")
for ((i=0; i<pkg_count; i++)); do
    name=$("$JQ" -r ".packages[$i].name" "$STATE_FILE")
    want_installed=$("$JQ" -r ".packages[$i].installed" "$STATE_FILE")
    [[ -z "$name" ]] && continue

    is_installed=false
    dpkg -s "$name" >/dev/null 2>&1 && is_installed=true

    if [[ "$want_installed" == "true" && "$is_installed" == "false" ]]; then
        echo "    [*] Installing $name..."
        apt-get install -y "$name" >/dev/null 2>&1 || true
        echo "    [+] Installed: $name"
    elif [[ "$want_installed" == "false" && "$is_installed" == "true" ]]; then
        echo "    [*] Removing $name..."
        apt-get remove -y "$name" >/dev/null 2>&1 || true
        echo "    [+] Removed: $name"
    fi

    # Services
    svc_count=$("$JQ" ".packages[$i].services | length" "$STATE_FILE")
    for ((j=0; j<svc_count; j++)); do
        sname=$("$JQ" -r ".packages[$i].services[$j].name" "$STATE_FILE")
        want_enabled=$("$JQ" -r ".packages[$i].services[$j].enabled" "$STATE_FILE")
        want_active=$("$JQ" -r ".packages[$i].services[$j].active" "$STATE_FILE")
        [[ -z "$sname" ]] && continue

        current_enabled=$(systemctl is-enabled "$sname" 2>/dev/null || echo "unknown")
        if [[ "$want_enabled" == "true" && "$current_enabled" != "enabled" ]]; then
            systemctl enable "$sname" >/dev/null 2>&1 || true
            echo "    [+] Enabled: $sname"
        elif [[ "$want_enabled" == "false" && "$current_enabled" == "enabled" ]]; then
            systemctl disable "$sname" >/dev/null 2>&1 || true
            echo "    [+] Disabled: $sname"
        fi

        current_active=$(systemctl is-active "$sname" 2>/dev/null || echo "unknown")
        if [[ "$want_active" == "true" && "$current_active" != "active" ]]; then
            systemctl start "$sname" >/dev/null 2>&1 || true
            echo "    [+] Started: $sname"
        elif [[ "$want_active" == "false" && "$current_active" == "active" ]]; then
            systemctl stop "$sname" >/dev/null 2>&1 || true
            echo "    [+] Stopped: $sname"
        fi
    done
done

# -------- FILES --------
file_count=$("$JQ" '.files | length' "$STATE_FILE")
for ((i=0; i<file_count; i++)); do
    path=$("$JQ" -r ".files[$i].path" "$STATE_FILE")
    exists=$("$JQ" -r ".files[$i].exists" "$STATE_FILE")
    [[ -z "$path" || "$exists" != "true" ]] && continue
    [[ ! -e "$path" ]] && continue

    owner=$("$JQ" -r ".files[$i].owner // empty" "$STATE_FILE")
    group=$("$JQ" -r ".files[$i].group // empty" "$STATE_FILE")
    mode=$("$JQ" -r ".files[$i].mode  // empty" "$STATE_FILE")

    if [[ -n "$owner" && -n "$group" ]]; then
        chown "$owner:$group" "$path" 2>/dev/null || true
        echo "    [+] chown $owner:$group $path"
    fi

    if [[ -n "$mode" ]]; then
        chmod "$mode" "$path" 2>/dev/null || true
        echo "    [+] chmod $mode $path"
    fi
done

# -------- FIREWALL --------
fw_keys=$("$JQ" -r '.firewalls | keys[]' "$STATE_FILE" 2>/dev/null)
for fw in $fw_keys; do
    content=$("$JQ" -r --arg k "$fw" '.firewalls[$k]' "$STATE_FILE")
    [[ -z "$content" ]] && continue

    case "$fw" in
        ufw)
            echo "    [*] Restoring ufw rules..."
            ufw --force reset >/dev/null 2>&1 || true
            # ufw rules: parse "Allow" / "Deny" lines
            while IFS= read -r line; do
                line="${line#"${line%%[![:space:]]*}"}"
                [[ -z "$line" ]] && continue
                [[ "$line" == \#* ]] && continue
                [[ "$line" == Status* ]] && continue
                # Only attempt lines that look like rules
                # shellcheck disable=SC2086
                ufw $line >/dev/null 2>&1 || true
            done <<< "$content"
            ufw --force enable >/dev/null 2>&1 || true
            echo "    [+] ufw restored"
            ;;
        iptables)
            echo "    [*] Restoring iptables rules..."
            if command -v iptables-restore >/dev/null 2>&1; then
                printf '%s' "$content" | iptables-restore >/dev/null 2>&1 || true
                echo "    [+] iptables restored"
            fi
            ;;
        nftables)
            echo "    [*] Restoring nftables rules..."
            if command -v nft >/dev/null 2>&1; then
                printf '%s' "$content" | nft -f - >/dev/null 2>&1 || true
                echo "    [+] nftables restored"
            fi
            ;;
    esac
done

# -------- DIRECTORIES (fstab edits for mount options) --------
dir_count=$("$JQ" '.directories | length' "$STATE_FILE")
for ((i=0; i<dir_count; i++)); do
    path=$("$JQ" -r ".directories[$i].path" "$STATE_FILE")
    mounted=$("$JQ" -r ".directories[$i].mounted" "$STATE_FILE")
    [[ "$mounted" != "true" ]] && continue

    missing_count=$("$JQ" ".directories[$i].missing_flags | length" "$STATE_FILE")
    [[ "$missing_count" -eq 0 ]] && continue

    # Build missing flags list
    missing_flags=()
    for ((m=0; m<missing_count; m++)); do
        flag=$("$JQ" -r ".directories[$i].missing_flags[$m]" "$STATE_FILE")
        [[ -n "$flag" ]] && missing_flags+=("$flag")
    done
    [[ ${#missing_flags[@]} -eq 0 ]] && continue

    # Edit fstab
    updated=false
    tmp_fstab=$(mktemp)
    while IFS= read -r line; do
        stripped="${line#"${line%%[![:space:]]*}"}"
        if [[ -z "$stripped" || "$stripped" == \#* ]]; then
            printf '%s\n' "$line" >> "$tmp_fstab"
            continue
        fi

        # Split into fields
        read -ra parts <<< "$line"
        if [[ "${#parts[@]}" -lt 4 ]]; then
            printf '%s\n' "$line" >> "$tmp_fstab"
            continue
        fi

        if [[ "${parts[1]}" == "$path" ]]; then
            IFS=',' read -ra opts <<< "${parts[3]}"
            for flag in "${missing_flags[@]}"; do
                found=false
                for o in "${opts[@]}"; do
                    [[ "$o" == "$flag" ]] && found=true
                done
                $found || opts+=("$flag")
            done
            parts[3]="$(IFS=,; echo "${opts[*]}")"
            printf '%s\n' "${parts[*]}" >> "$tmp_fstab"
            updated=true
            echo "    [+] fstab updated for $path: added ${missing_flags[*]}"
        else
            printf '%s\n' "$line" >> "$tmp_fstab"
        fi
    done < /etc/fstab

    if $updated; then
        cat "$tmp_fstab" > /etc/fstab
        mount -o remount "$path" >/dev/null 2>&1 || true
        echo "    [+] Remounted: $path"
    fi
    rm -f "$tmp_fstab"
done

# -------- USERS --------
user_count=$("$JQ" '.users | length' "$STATE_FILE")
for ((i=0; i<user_count; i++)); do
    name=$("$JQ" -r ".users[$i].name" "$STATE_FILE")
    uid=$("$JQ" -r ".users[$i].uid"  "$STATE_FILE")
    gid=$("$JQ" -r ".users[$i].gid"  "$STATE_FILE")
    home=$("$JQ" -r ".users[$i].home"  "$STATE_FILE")
    shell=$("$JQ" -r ".users[$i].shell" "$STATE_FILE")
    [[ -z "$name" ]] && continue

    if getent passwd "$name" >/dev/null 2>&1; then
        usermod -u "$uid" -g "$gid" -d "$home" -s "$shell" "$name" >/dev/null 2>&1 || true
        echo "    [+] Updated user: $name"
    else
        useradd -u "$uid" -g "$gid" -d "$home" -s "$shell" "$name" >/dev/null 2>&1 || true
        echo "    [+] Created user: $name"
    fi
done

# -------- GROUPS --------
grp_count=$("$JQ" '.groups | length' "$STATE_FILE")
for ((i=0; i<grp_count; i++)); do
    name=$("$JQ" -r ".groups[$i].name" "$STATE_FILE")
    gid=$("$JQ" -r ".groups[$i].gid"  "$STATE_FILE")
    [[ -z "$name" ]] && continue

    if getent group "$name" >/dev/null 2>&1; then
        groupmod -g "$gid" "$name" >/dev/null 2>&1 || true
        echo "    [+] Updated group: $name"
    else
        groupadd -g "$gid" "$name" >/dev/null 2>&1 || true
        echo "    [+] Created group: $name"
    fi

    members_count=$("$JQ" ".groups[$i].members | length" "$STATE_FILE")
    for ((m=0; m<members_count; m++)); do
        member=$("$JQ" -r ".groups[$i].members[$m]" "$STATE_FILE")
        [[ -z "$member" ]] && continue
        usermod -aG "$name" "$member" >/dev/null 2>&1 || true
    done
done

echo ""
echo "[+] Restore complete"

# ---------- APPLY SYSCTL ----------
if command -v sysctl &>/dev/null; then
    sysctl --system >/dev/null 2>&1 || true
fi
