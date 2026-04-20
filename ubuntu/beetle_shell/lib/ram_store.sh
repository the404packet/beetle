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
LOGGING_RAM_STORE="/dev/shm/beetle_logging_store"

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

ipv6 = data.get("network_services", {}).get("ipv6", {})
print(f'NS_ipv6_status={ipv6.get("status", "enabled")}')
keys = ipv6.get("disable_sysctl_keys", [])
print(f'NS_ipv6_sysctl_count={len(keys)}')
for idx, key in enumerate(keys):
    print(f'NS_ipv6_sysctl_{idx}={key}')

wireless = data.get("network_services", {}).get("wireless", {})
print(f'NS_wireless_restrict={str(wireless.get("restrict", True)).lower()}')

bluetooth = data.get("network_services", {}).get("bluetooth", {})
print(f'NS_bluetooth_package={bluetooth.get("package", "")}')
print(f'NS_bluetooth_service={bluetooth.get("service", "")}')
print(f'NS_bluetooth_restrict={str(bluetooth.get("restrict", True)).lower()}')

modules = data.get("kernel_modules", [])
print(f'KM_count={len(modules)}')
for idx, mod in enumerate(modules):
    print(f'KM_{idx}_name={mod.get("name", "")}')
    print(f'KM_{idx}_type={mod.get("type", "")}')
    print(f'KM_{idx}_restrict={str(mod.get("restrict", True)).lower()}')

net_params = data.get("network_parameters", {})

sysctl_conf = net_params.get("sysctl_conf_file", "/etc/sysctl.d/60-netipv4_sysctl.conf")
sysctl_conf_ipv6 = net_params.get("sysctl_conf_file_ipv6", "/etc/sysctl.d/60-netipv6_sysctl.conf")
print(f'NP_sysctl_conf={sysctl_conf}')
print(f'NP_sysctl_conf_ipv6={sysctl_conf_ipv6}')

for section in ["ipv4", "ipv6"]:
    params = net_params.get(section, [])
    print(f'NP_{section}_count={len(params)}')
    for idx, param in enumerate(params):
        name = param.get("name", "")
        value = param.get("value", "")
        flush = param.get("flush", "")
        name_key = name.replace(".", "_")
        print(f'NP_{section}_{idx}_name={name}')
        print(f'NP_{section}_{idx}_value={value}')
        print(f'NP_{section}_{idx}_flush={flush}')
        print(f'NP_{section}_{idx}_key={name_key}')
EOF

    chmod 600 "$NETWORK_RAM_STORE"
    source "$NETWORK_RAM_STORE"
}

unload_json_network() {
    [ -f "$NETWORK_RAM_STORE" ] && shred -u "$NETWORK_RAM_STORE" 2>/dev/null || rm -f "$NETWORK_RAM_STORE"
}

check_ipv6_disabled() {
    if grep -Pqs -- '^\h*0\b' /sys/module/ipv6/parameters/disable; then
        echo "no"
        return
    fi
    if sysctl net.ipv6.conf.all.disable_ipv6 2>/dev/null | \
       grep -Pqs -- '^\h*net\.ipv6\.conf\.all\.disable_ipv6\h*=\h*1\b' && \
       sysctl net.ipv6.conf.default.disable_ipv6 2>/dev/null | \
       grep -Pqs -- '^\h*net\.ipv6\.conf\.default\.disable_ipv6\h*=\h*1\b'; then
        echo "yes"
        return
    fi
    echo "no"
}

network_audit_sysctl_param() {
    local name="$1" value="$2"
    local actual
    actual=$(sysctl "$name" 2>/dev/null | awk -F= '{print $2}' | xargs)
    [ "$actual" == "$value" ] && return 0 || return 1
}

network_audit_sysctl_file() {
    local name="$1" value="$2"
    local l_systemdsysctl
    l_systemdsysctl="$(readlink -f /lib/systemd/systemd-sysctl)"
    local l_ufwscf
    l_ufwscf="$([ -f /etc/default/ufw ] && \
        awk -F= '/^\s*IPT_SYSCTL=/{print $2}' /etc/default/ufw)"

    local found=false
    while read -r l_out; do
        [ -z "$l_out" ] && continue
        if [[ "$l_out" =~ ^\s*# ]]; then
            l_file="${l_out//# /}"
        else
            l_kpar="$(awk -F= '{print $1}' <<< "$l_out" | xargs)"
            if [ "$l_kpar" == "$name" ]; then
                l_val="$(awk -F= '{print $2}' <<< "$l_out" | xargs)"
                [ "$l_val" == "$value" ] && found=true
            fi
        fi
    done < <("$l_systemdsysctl" --cat-config 2>/dev/null | \
        grep -Po '^\h*([^#\n\r]+|#\h*\/[^#\n\r\h]+\.conf\b)')

    if [ -n "$l_ufwscf" ]; then
        l_kpar="$(grep -Po "^\h*$name\b" "$l_ufwscf" 2>/dev/null | xargs)"
        l_kpar="${l_kpar//\//.}"
        if [ "$l_kpar" == "$name" ]; then
            l_val="$(grep -Po "^\h*$name\h*=\h*\K\H+" "$l_ufwscf" 2>/dev/null | xargs)"
            [ "$l_val" == "$value" ] && found=true
        fi
    fi

    $found && return 0 || return 1
}

network_harden_sysctl_param() {
    local name="$1" value="$2" flush="$3" conf_file="$4"

    sysctl -w "${name}=${value}" &>/dev/null
    [ -n "$flush" ] && sysctl -w "${flush}=1" &>/dev/null

    if grep -Pq "^\s*${name}\s*=" "$conf_file" 2>/dev/null; then
        sed -i "s|^\s*${name}\s*=.*|${name} = ${value}|" "$conf_file"
    else
        echo "${name} = ${value}" >> "$conf_file"
    fi
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

job_service = data.get("job_service", {})
daemons = job_service.get("daemons", [])
print(f'JS_daemon_count={len(daemons)}')
any_required = any(d.get("required", False) for d in daemons)
print(f'JS_daemon_any_required={"true" if any_required else "false"}')
for idx, daemon in enumerate(daemons):
    name    = daemon.get("name", "")
    package = daemon.get("package", "")
    service = daemon.get("service", "")
    required = daemon.get("required", False)
    name_key = name.replace("-", "_").replace(".", "_")
    print(f'JS_daemon_{idx}_name={name}')
    print(f'JS_daemon_{idx}_package={package}')
    print(f'JS_daemon_{idx}_service={service}')
    print(f'JS_daemon_{idx}_required={str(required).lower()}')
    print(f'JS_daemon_name_{name_key}_idx={idx}')

cron_dirs = job_service.get("cron_dirs", [])
print(f'JS_cron_dir_count={len(cron_dirs)}')
for idx, entry in enumerate(cron_dirs):
    print(f'JS_cron_dir_{idx}_file={entry.get("file", "")}')
    print(f'JS_cron_dir_{idx}_mode={entry.get("mode", "")}')
    print(f'JS_cron_dir_{idx}_owner={entry.get("owner", "")}')
    print(f'JS_cron_dir_{idx}_group={entry.get("group", "")}')

for section_key in ["cron_access", "at_access"]:
    section = job_service.get(section_key, {})
    sk = section_key
    print(f'JS_{sk}_allow_file={section.get("allow_file", "")}')
    print(f'JS_{sk}_deny_file={section.get("deny_file", "")}')
    print(f'JS_{sk}_mode={section.get("mode", "")}')
    print(f'JS_{sk}_owner={section.get("owner", "")}')
    groups = section.get("groups", [])
    print(f'JS_{sk}_group_count={len(groups)}')
    for gidx, grp in enumerate(groups):
        print(f'JS_{sk}_group_{gidx}={grp}')

time_sync = data.get("time_sync", {})
ts_daemons = time_sync.get("daemons", [])
ts_policy = time_sync.get("policy", "exactly_one")
print(f'TS_policy={ts_policy}')
print(f'TS_daemon_count={len(ts_daemons)}')
for idx, daemon in enumerate(ts_daemons):
    name_key = daemon.get("name","").replace("-","_").replace(".","_")
    print(f'TS_daemon_{idx}_name={daemon.get("name","")}')
    print(f'TS_daemon_{idx}_package={daemon.get("package","")}')
    print(f'TS_daemon_{idx}_service={daemon.get("service","")}')
    print(f'TS_daemon_{idx}_config_file={daemon.get("config_file","")}')
    print(f'TS_daemon_{idx}_config_dir={daemon.get("config_dir","")}')
    print(f'TS_daemon_{idx}_run_as_user={daemon.get("run_as_user","")}')
    ntp = daemon.get("ntp_servers",[])
    fallback = daemon.get("fallback_servers",[])
    print(f'TS_daemon_{idx}_ntp_count={len(ntp)}')
    for nidx, srv in enumerate(ntp):
        print(f'TS_daemon_{idx}_ntp_{nidx}={srv}')
    print(f'TS_daemon_{idx}_fallback_count={len(fallback)}')
    for fidx, srv in enumerate(fallback):
        print(f'TS_daemon_{idx}_fallback_{fidx}={srv}')
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

load_json_logging() {
    local json_file="$1"
    [ -f "$json_file" ] || { echo "ERROR: logging JSON not found: $json_file"; return 1; }
    python3 -c "
import json
with open('$json_file') as f:
    data = json.load(f)
jd = data.get('journald', {})
print('LJ_service='       + jd.get('service',''))
print('LJ_config_file='   + jd.get('config_file',''))
print('LJ_config_drop_dir=' + jd.get('config_drop_dir',''))
print('LJ_tmpfiles_config=' + jd.get('tmpfiles_config',''))
print('LJ_tmpfiles_source=' + jd.get('tmpfiles_source',''))
rp = jd.get('rotation_params', [])
print('LJ_rot_count=' + str(len(rp)))
for i,p in enumerate(rp):
    print(f'LJ_rot_{i}_key='   + p.get('key',''))
    print(f'LJ_rot_{i}_value=' + p.get('value',''))
" > "$LOGGING_RAM_STORE"
    chmod 600 "$LOGGING_RAM_STORE"
    source "$LOGGING_RAM_STORE"
}

unload_json_logging() {
    rm -f "$LOGGING_RAM_STORE"
    unset $(compgen -v | grep '^LJ_')
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