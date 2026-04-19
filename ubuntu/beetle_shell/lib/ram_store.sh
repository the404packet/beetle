# ─────────────────────────────────────────────
# Per-type RAM store paths
# ─────────────────────────────────────────────
DPKG_RAM_STORE="/dev/shm/beetle_dpkg.env"
SEVERITY_RAM_STORE="/dev/shm/beetle_severity.env"
PERM_RAM_STORE="/dev/shm/beetle_permissions.env"          # system_maintenance
NETWORK_RAM_STORE="/dev/shm/beetle_network.env"           # network
SERVICES_RAM_STORE="/dev/shm/beetle_services.env"         # services
ACCESS_RAM_STORE="/dev/shm/beetle_access_control.env"     # access_control
FIREWALL_RAM_STORE="/dev/shm/beetle_firewall.env"         # host_based_firewall

SEVERITY_CONFIG_DIR="/etc/beetle"
export DPKG_RAM_STORE SEVERITY_RAM_STORE PERM_RAM_STORE \
       NETWORK_RAM_STORE SERVICES_RAM_STORE ACCESS_RAM_STORE FIREWALL_RAM_STORE

load_dpkg() {
    rm -f "$DPKG_RAM_STORE"

    dpkg-query -W -f='${Package} ${Status} ${Version}\n' 2>/dev/null | \
    awk '$0 ~ /install ok installed/ {print $1, $NF}' | \
    while read -r pkg ver; do
        echo "PKG_${pkg//[^a-zA-Z0-9_]/_}=installed"
        echo "PKG_${pkg//[^a-zA-Z0-9_]/_}_version=${ver}"
    done > "$DPKG_RAM_STORE"

    chmod 600 "$DPKG_RAM_STORE"
    source "$DPKG_RAM_STORE"
}

get_installed_version() {
    local pkg="$1"
    local key="PKG_${pkg//[^a-zA-Z0-9_]/_}_version"
    echo "${!key}"
}

unload_dpkg() {
    [ -f "$DPKG_RAM_STORE" ] && shred -u "$DPKG_RAM_STORE" 2>/dev/null || rm -f "$DPKG_RAM_STORE"
}

is_package_installed() {
    local pkg="$1"
    local key="PKG_${pkg//[^a-zA-Z0-9_]/_}"
    [ "${!key}" = "installed" ]
}

unset_package() {
    local pkg="$1"
    local key="PKG_${pkg//[^a-zA-Z0-9_]/_}"
    unset "$key"
    unset "${key}_version"
}

# ─────────────────────────────────────────────
# SEVERITY: Load severity config into RAM
# ─────────────────────────────────────────────
load_severity() {
    local target_level="$1"
    rm -f "$SEVERITY_RAM_STORE"

    local levels=("basic")
    [[ "$target_level" == "moderate" ]] && levels=("basic" "moderate")
    [[ "$target_level" == "strict"   ]] && levels=("basic" "moderate" "strict")

    local levels_str
    levels_str=$(printf '"%s",' "${levels[@]}")
    levels_str="[${levels_str%,}]"

    python3 - <<EOF > "$SEVERITY_RAM_STORE"
import json, os

level_list = ${levels_str}
config_dir = "$SEVERITY_CONFIG_DIR"
checks = {}

for level in level_list:
    config = os.path.join(config_dir, f"severity_{level}.json")
    if not os.path.exists(config):
        continue
    with open(config) as f:
        data = json.load(f)
    for key, enabled in data.items():
        checks[key] = enabled

for key, enabled in checks.items():
    safe_key = key.replace("/", "__").replace("-", "_").replace(".", "_")
    print(f'SEV_{safe_key}={"true" if enabled else "false"}')
EOF

    chmod 600 "$SEVERITY_RAM_STORE"
    source "$SEVERITY_RAM_STORE"
}

unload_severity() {
    [ -f "$SEVERITY_RAM_STORE" ] && shred -u "$SEVERITY_RAM_STORE" 2>/dev/null || rm -f "$SEVERITY_RAM_STORE"
}

is_check_enabled() {
    local script_path="$1"

    [ -f "$SEVERITY_RAM_STORE" ] && source "$SEVERITY_RAM_STORE"

    local script_name
    script_name=$(basename "$script_path" .sh)

    local rel_path="${script_path#$BEETLE_SHELL_ROOT/}"
    rel_path="${rel_path#audit/}"
    rel_path="${rel_path#harden/}"

    local folder
    folder=$(dirname "$rel_path")

    local key="${folder}/${script_name}"

    # Must normalize exactly the same way as python in load_severity
    # python does: / -> __ , - -> _ , . -> _
    local safe_key
    safe_key=$(echo "$key" | sed 's|/|__|g; s|-|_|g; s|\.|_|g')

    local var="SEV_${safe_key}"
    local val="${!var}"

    # Debug — uncomment to troubleshoot
    # echo "DEBUG key=$key safe_key=$safe_key var=$var val=$val" >&2

    [ -z "$val" ] && return 1
    [ "$val" == "true" ]
}

# ─────────────────────────────────────────────
# NETWORK JSON loader/unloader/getter
# ─────────────────────────────────────────────
load_json_network() {
    local json_file="$1"
    [ -f "$json_file" ] || { echo "ERROR: JSON not found: $json_file"; return 1; }
    rm -f "$NETWORK_RAM_STORE"

    python3 - <<EOF > "$NETWORK_RAM_STORE"
import json
with open("$json_file") as f:
    data = json.load(f)
# Adjust the key name below to match your actual network.json structure
for entry in data.get("network_settings", []):
    key = entry["name"].replace("/", "_").replace("-", "_").replace(".", "_").lstrip("_")
    for field, val in entry.items():
        if field == "name":
            continue
        print(f'NET_{key}_{field}={val}')
EOF

    chmod 600 "$NETWORK_RAM_STORE"
    source "$NETWORK_RAM_STORE"
}

unload_json_network() {
    [ -f "$NETWORK_RAM_STORE" ] && shred -u "$NETWORK_RAM_STORE" 2>/dev/null || rm -f "$NETWORK_RAM_STORE"
}

get_net() {
    local name="$1" field="$2"
    local key; key=$(echo "$name" | sed 's|/|_|g; s|-|_|g; s|\.|_|g; s|^_||')
    local var="NET_${key}_${field}"
    echo "${!var}"
}

# ─────────────────────────────────────────────
# SERVICES JSON loader/unloader/getter
# ─────────────────────────────────────────────
load_json_services() {
    local json_file="$1"
    [ -f "$json_file" ] || { echo "ERROR: JSON not found: $json_file"; return 1; }
    rm -f "$SERVICES_RAM_STORE"

    python3 - <<EOF > "$SERVICES_RAM_STORE"
import json
with open("$json_file") as f:
    data = json.load(f)

for section in ["server_services", "client_services"]:
    for category, packages in data.get(section, {}).items():
        cat_key = category.replace("/", "_").replace("-", "_").replace(".", "_").lstrip("_")
        print(f'SS_{cat_key}_pkg_count={len(packages)}')
        for pkg_idx, (pkg_name, fields) in enumerate(packages.items()):
            pkg_key = pkg_name.replace("/", "_").replace("-", "_").replace(".", "_").lstrip("_")
            restrict = fields.get("restrict", True)
            version  = fields.get("version", "null")
            services = fields.get("services", [])
            print(f'SS_{cat_key}_pkg_{pkg_idx}={pkg_name}')
            print(f'SS_{cat_key}_{pkg_key}_restrict={str(restrict).lower()}')
            print(f'SS_{cat_key}_{pkg_key}_version={version if version else "null"}')
            print(f'SS_{cat_key}_{pkg_key}_svc_count={len(services)}')
            for svc_idx, svc in enumerate(services):
                print(f'SS_{cat_key}_{pkg_key}_svc_{svc_idx}={svc}')
EOF

    chmod 600 "$SERVICES_RAM_STORE"
    source "$SERVICES_RAM_STORE"
}

unload_json_services() {
    [ -f "$SERVICES_RAM_STORE" ] && shred -u "$SERVICES_RAM_STORE" 2>/dev/null || rm -f "$SERVICES_RAM_STORE"
}

get_svc() {
    local category="$1" package="$2" field="$3"
    local cat_key; cat_key=$(echo "$category" | sed 's|/|_|g; s|-|_|g; s|\.|_|g; s|^_||')
    local pkg_key; pkg_key=$(echo "$package" | sed 's|/|_|g; s|-|_|g; s|\.|_|g; s|^_||')
    local var="SS_${cat_key}_${pkg_key}_${field}"
    echo "${!var}"
}

get_svc_packages() {
    local category="$1"
    local cat_key; cat_key=$(echo "$category" | sed 's|/|_|g; s|-|_|g; s|\.|_|g; s|^_||')
    local count_var="SS_${cat_key}_pkg_count"
    local count="${!count_var}"
    for ((i=0; i<count; i++)); do
        local pkg_var="SS_${cat_key}_pkg_${i}"
        echo "${!pkg_var}"
    done
}

get_svc_services() {
    local category="$1" package="$2"
    local cat_key; cat_key=$(echo "$category" | sed 's|/|_|g; s|-|_|g; s|\.|_|g; s|^_||')
    local pkg_key; pkg_key=$(echo "$package" | sed 's|/|_|g; s|-|_|g; s|\.|_|g; s|^_||')
    local count_var="SS_${cat_key}_${pkg_key}_svc_count"
    local count="${!count_var}"
    for ((i=0; i<count; i++)); do
        local svc_var="SS_${cat_key}_${pkg_key}_svc_${i}"
        echo "${!svc_var}"
    done
}


is_version_ok() {
    local pkg="$1" required="$2"
    [[ "$required" == "null" || -z "$required" ]] && return 0
    local installed
    installed=$(get_installed_version "$pkg")
    [ -z "$installed" ] && return 1
    printf '%s\n%s' "$required" "$installed" | sort -V | head -1 | grep -qx "$required"
}
# ─────────────────────────────────────────────
# ACCESS CONTROL JSON loader/unloader/getter
# ─────────────────────────────────────────────
load_json_access_control() {
    local json_file="$1"
    [ -f "$json_file" ] || { echo "ERROR: JSON not found: $json_file"; return 1; }
    rm -f "$ACCESS_RAM_STORE"

    python3 - <<EOF > "$ACCESS_RAM_STORE"
import json
with open("$json_file") as f:
    data = json.load(f)
for entry in data.get("access_control", []):
    key = entry["name"].replace("/", "_").replace("-", "_").replace(".", "_").lstrip("_")
    for field, val in entry.items():
        if field == "name":
            continue
        print(f'ACC_{key}_{field}={val}')
EOF

    chmod 600 "$ACCESS_RAM_STORE"
    source "$ACCESS_RAM_STORE"
}

unload_json_access_control() {
    [ -f "$ACCESS_RAM_STORE" ] && shred -u "$ACCESS_RAM_STORE" 2>/dev/null || rm -f "$ACCESS_RAM_STORE"
}

get_acc() {
    local name="$1" field="$2"
    local key; key=$(echo "$name" | sed 's|/|_|g; s|-|_|g; s|\.|_|g; s|^_||')
    local var="ACC_${key}_${field}"
    echo "${!var}"
}

# ─────────────────────────────────────────────
# HOST-BASED FIREWALL JSON loader/unloader/getter
# ─────────────────────────────────────────────
load_json_host_based_firewall() {
    local json_file="$1"
    [ -f "$json_file" ] || { echo "ERROR: JSON not found: $json_file"; return 1; }
    rm -f "$FIREWALL_RAM_STORE"

    python3 - <<EOF > "$FIREWALL_RAM_STORE"
import json
with open("$json_file") as f:
    data = json.load(f)
for entry in data.get("firewall_rules", []):
    key = entry["name"].replace("/", "_").replace("-", "_").replace(".", "_").lstrip("_")
    for field, val in entry.items():
        if field == "name":
            continue
        print(f'FW_{key}_{field}={val}')
EOF

    chmod 600 "$FIREWALL_RAM_STORE"
    source "$FIREWALL_RAM_STORE"
}

unload_json_host_based_firewall() {
    [ -f "$FIREWALL_RAM_STORE" ] && shred -u "$FIREWALL_RAM_STORE" 2>/dev/null || rm -f "$FIREWALL_RAM_STORE"
}

get_fw() {
    local name="$1" field="$2"
    local key; key=$(echo "$name" | sed 's|/|_|g; s|-|_|g; s|\.|_|g; s|^_||')
    local var="FW_${key}_${field}"
    echo "${!var}"
}

# ─────────────────────────────────────────────
# SYSTEM MAINTENANCE JSON loader/unloader/getter
# ─────────────────────────────────────────────
load_json_system_maintenance() {
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

unload_json_system_maintenance() {
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
# GENERIC DISPATCHER — audit.sh calls only these
# json_tag is the part before :: from find_module_json
# ─────────────────────────────────────────────
load_module_json() {
    local json_type="$1"
    local json_file="$2"
    # Calls load_json_<type> — adding a new type = add a new loader above, nothing else
    local fn="load_json_${json_type}"
    if declare -f "$fn" > /dev/null; then
        "$fn" "$json_file"
    else
        echo "ERROR: No loader found for json type: $json_type" >&2
        return 1
    fi
}

unload_module_json() {
    local json_type="$1"
    local fn="unload_json_${json_type}"
    if declare -f "$fn" > /dev/null; then
        "$fn"
    fi
}

unload_all() {
    unload_dpkg
    unload_json_system_maintenance
    unload_json_network
    unload_json_services
    unload_json_access_control
    unload_json_host_based_firewall
    unload_severity
}

export -f load_module_json
export -f unload_module_json
export -f load_dpkg unload_dpkg is_package_installed get_installed_version unset_package
export -f load_severity unload_severity is_check_enabled
export -f load_json_system_maintenance unload_json_system_maintenance get_perm
export -f load_json_network unload_json_network get_net
export -f load_json_services unload_json_services get_svc get_svc_services is_version_ok get_svc_packages
export -f load_json_access_control  unload_json_access_control  get_acc
export -f load_json_host_based_firewall unload_json_host_based_firewall get_fw
export -f unload_all