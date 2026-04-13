#!/usr/bin/env bash

# RAM store paths (all in tmpfs)
DPKG_RAM_STORE="/dev/shm/beetle_dpkg.env"
PERM_RAM_STORE="/dev/shm/beetle_permissions.env"

# ─────────────────────────────────────────────
# DPKG: Load all installed packages into RAM
# ─────────────────────────────────────────────
load_dpkg() {
    rm -f "$DPKG_RAM_STORE"

    dpkg-query -W -f='${Package} ${Status}\n' 2>/dev/null | \
    awk '$NF=="installed" {print $1}' | \
    while read -r pkg; do
        echo "PKG_${pkg//[^a-zA-Z0-9_]/_}=installed"
    done > "$DPKG_RAM_STORE"

    chmod 600 "$DPKG_RAM_STORE"
    source "$DPKG_RAM_STORE"
}

unload_dpkg() {
    [ -f "$DPKG_RAM_STORE" ] && shred -u "$DPKG_RAM_STORE" 2>/dev/null || rm -f "$DPKG_RAM_STORE"
}

is_package_installed() {
    local pkg="$1"
    local key="PKG_${pkg//[^a-zA-Z0-9_]/_}"
    [ "${!key}" = "installed" ]
}

# ─────────────────────────────────────────────
# JSON: Load a specific permissions JSON into RAM
# ─────────────────────────────────────────────
load_json_permissions() {
    local json_file="$1"

    [ -f "$json_file" ] || { echo "ERROR: JSON not found: $json_file"; return 1; }

    rm -f "$PERM_RAM_STORE"

    python3 - <<EOF > "$PERM_RAM_STORE"
import json

with open("$json_file") as f:
    data = json.load(f)

for entry in data["system_file_permissions"]:
    key = entry["file"].replace("/", "_").replace("-", "_").replace(".", "_").lstrip("_")
    mode  = entry["mode"]
    owner = entry["owner"]
    group = entry["group"].replace("root/shadow", "shadow")
    print(f'PERM_{key}_mode={mode}')
    print(f'PERM_{key}_owner={owner}')
    print(f'PERM_{key}_group={group}')
EOF

    chmod 600 "$PERM_RAM_STORE"
    source "$PERM_RAM_STORE"
}

unload_json_permissions() {
    [ -f "$PERM_RAM_STORE" ] && shred -u "$PERM_RAM_STORE" 2>/dev/null || rm -f "$PERM_RAM_STORE"
}

get_perm() {
    local file="$1"
    local field="$2"
    local key
    key=$(echo "$file" | sed 's|/|_|g; s|-|_|g; s|\.|_|g; s|^_||')
    local var="PERM_${key}_${field}"
    echo "${!var}"
}

# ─────────────────────────────────────────────
# CLEANUP: Remove everything from RAM
# ─────────────────────────────────────────────
unload_all() {
    unload_dpkg
    unload_json_permissions
}

export -f load_dpkg
export -f unload_dpkg
export -f is_package_installed
export -f load_json_permissions
export -f unload_json_permissions
export -f get_perm
export -f unload_all