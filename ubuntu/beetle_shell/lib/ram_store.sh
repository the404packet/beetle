# ─────────────────────────────────────────────
# Per-type RAM store paths
# ─────────────────────────────────────────────
DPKG_RAM_STORE="/dev/shm/beetle_dpkg.env"
SEVERITY_RAM_STORE="/dev/shm/beetle_severity.env"
PERM_RAM_STORE="/dev/shm/beetle_permissions.env"          # system_maintenance
SSH_RAM_STORE="/dev/shm/beetle_ssh.env"
NETWORK_RAM_STORE="/dev/shm/beetle_network.env"           # network
SERVICES_RAM_STORE="/dev/shm/beetle_services.env"         # services
FIREWALL_RAM_STORE="/dev/shm/beetle_firewall.env"         # host_based_firewall
LOGGING_RAM_STORE="/dev/shm/beetle_logging_store.env"
INITIAL_SETUP_RAM_STORE="/dev/shm/beetle_initial_setup_store.env"

SEVERITY_CONFIG_DIR="/etc/beetle"
export DPKG_RAM_STORE SEVERITY_RAM_STORE PERM_RAM_STORE \
       NETWORK_RAM_STORE SERVICES_RAM_STORE ACCESS_RAM_STORE FIREWALL_RAM_STORE LOGGING_RAM_STORE

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

load_json_initial_setup() {
    local json_file="$1"
    [ -f "$json_file" ] || { echo "ERROR: initial_setup JSON not found: $json_file"; return 1; }

    local py_script
    py_script=$(mktemp /tmp/beetle_loader_XXXXXX.py)
    cat > "$py_script" << 'PYEOF'
import json, sys

def q(v):
    return "'" + str(v).replace("'", "'\\''") + "'"

with open(sys.argv[1]) as f:
    data = json.load(f)

aa = data.get('apparmor', {})
print('AA_grub_config='      + q(aa.get('grub_config','')))
print('AA_grub_cfg='         + q(aa.get('grub_cfg','')))
print('AA_grub_cmdline_key=' + q(aa.get('grub_cmdline_key','')))
print('AA_profiles_dir='     + q(aa.get('profiles_dir','')))
print('AA_enforce_mode='     + q(aa.get('enforce_mode','')))
print('AA_complain_mode='    + q(aa.get('complain_mode','')))

pkgs = aa.get('packages', [])
print('AA_pkg_count=' + q(len(pkgs)))
for i,p in enumerate(pkgs):
    print(f'AA_pkg_{i}_name=' + q(p.get('name','')))

gp = aa.get('grub_params', [])
print('AA_grub_param_count=' + q(len(gp)))
for i,p in enumerate(gp):
    print(f'AA_grub_{i}_name='  + q(p.get('name','')))
    print(f'AA_grub_{i}_value=' + q(p.get('value','')))
fm = data.get('filesystem_modules', {})
print('FM_modprobe_dir=' + q(fm.get('modprobe_dir','')))
mods = fm.get('modules', [])
print('FM_count=' + q(len(mods)))
for i,m in enumerate(mods):
    print(f'FM_{i}_name=' + q(m.get('name','')))
    print(f'FM_{i}_type=' + q(m.get('type','')))
fp = data.get('filesystem_partitions', {})
parts = fp.get('partitions', [])
print('FP_count=' + q(len(parts)))
for i, p in enumerate(parts):
    mount = p.get('mount', '')
    mount_key = mount.replace('/', '_').lstrip('_')
    print(f'FP_{i}_mount=' + q(mount))
    print(f'FP_{i}_mount_key=' + q(mount_key))
    print(f'FP_{i}_required=' + q(str(p.get('required', False)).lower()))
    print(f'FP_{i}_systemd_unit=' + q(p.get('systemd_unit') or ''))
    opts = p.get('options', [])
    print(f'FP_{i}_opt_count=' + q(len(opts)))
    for j, opt in enumerate(opts):
        print(f'FP_{i}_opt_{j}=' + q(opt))
    # also store mount->idx mapping for easy lookup
    print(f'FP_idx_{mount_key}=' + q(i))
gd = data.get('gdm', {})
print('GD_package='           + q(gd.get('package','')))
print('GD_profile_dir='       + q(gd.get('profile_dir','')))
print('GD_profile_file='      + q(gd.get('profile_file','')))
print('GD_db_dir='            + q(gd.get('db_dir','')))
print('GD_locks_dir='         + q(gd.get('locks_dir','')))
print('GD_gdm_db_dir='        + q(gd.get('gdm_db_dir','')))
print('GD_banner_file='       + q(gd.get('banner_file','')))
print('GD_login_screen_file=' + q(gd.get('login_screen_file','')))
print('GD_screensaver_file='  + q(gd.get('screensaver_file','')))
print('GD_screensaver_lock='  + q(gd.get('screensaver_lock','')))
print('GD_automount_file='    + q(gd.get('automount_file','')))
print('GD_automount_lock='    + q(gd.get('automount_lock','')))
print('GD_autorun_file='      + q(gd.get('autorun_file','')))
print('GD_autorun_lock='      + q(gd.get('autorun_lock','')))
print('GD_banner_text='       + q(gd.get('banner_text','')))
print('GD_idle_delay='        + q(gd.get('idle_delay',900)))
print('GD_lock_delay='        + q(gd.get('lock_delay',5)))
xdmcp = gd.get('xdmcp_configs', [])
print('GD_xdmcp_count=' + q(len(xdmcp)))
for i,x in enumerate(xdmcp):
    print(f'GD_xdmcp_{i}=' + q(x))
PYEOF

    python3 "$py_script" "$json_file" > "$INITIAL_SETUP_RAM_STORE"
    local exit_code=$?
    rm -f "$py_script"
    [ $exit_code -ne 0 ] && { echo "ERROR: failed to parse $json_file"; return 1; }
    chmod 600 "$INITIAL_SETUP_RAM_STORE"
    source "$INITIAL_SETUP_RAM_STORE"
}

get_partition_idx() {
    local mount="$1"
    local key; key=$(echo "$mount" | sed 's|/|_|g; s|^_||')
    local var="FP_idx_${key}"
    echo "${!var}"
}

is_partition_mounted() {
    local mount="$1"
    findmnt -kn "$mount" &>/dev/null
}

partition_has_option() {
    local mount="$1" option="$2"
    findmnt -kn "$mount" | grep -qv "$option" && return 1 || return 0
}

gdm_installed() {
    is_package_installed "gdm3"
}

unload_json_initial_setup() {
    rm -f "$INITIAL_SETUP_RAM_STORE"
    unset $(compgen -v | grep -E '^(AA_|FM_|PT_|GD_)')
}

beetle_module_audit() {
    local mod_name="$1" mod_type="$2"
    local mod_path
    mod_path="$(readlink -f /lib/modules/**/kernel/"$mod_type" 2>/dev/null | sort -u)"
    local found=0

    for base_dir in $mod_path; do
        local check_dir="${base_dir}/${mod_name//-//}"
        if [ -d "$check_dir" ] && [ -n "$(ls -A "$check_dir" 2>/dev/null)" ]; then
            found=1
            local mod_chk_name="$mod_name"
            [[ "$mod_name" =~ overlay ]] && mod_chk_name="${mod_name::-2}"
            local showconfig
            showconfig=$(modprobe --showconfig 2>/dev/null \
                | grep -P "\b(install|blacklist)\h+${mod_chk_name//-/_}\b")

            lsmod 2>/dev/null | grep -q "$mod_chk_name" && return 1
            echo "$showconfig" | grep -Pq "\binstall\h+${mod_chk_name//-/_}\h+(\/usr)?\/bin\/(true|false)\b" || return 1
            echo "$showconfig" | grep -Pq "\bblacklist\h+${mod_chk_name//-/_}\b" || return 1
        fi
    done
    return 0
}

beetle_module_harden() {
    local mod_name="$1" mod_type="$2" modprobe_dir="$3"
    local mod_path
    mod_path="$(readlink -f /lib/modules/**/kernel/"$mod_type" 2>/dev/null | sort -u)"

    for base_dir in $mod_path; do
        local check_dir="${base_dir}/${mod_name//-//}"
        if [ -d "$check_dir" ] && [ -n "$(ls -A "$check_dir" 2>/dev/null)" ]; then
            local mod_chk_name="$mod_name"
            [[ "$mod_name" =~ overlay ]] && mod_chk_name="${mod_name::-2}"
            local conf_file="${modprobe_dir}/${mod_name}.conf"
            local showconfig
            showconfig=$(modprobe --showconfig 2>/dev/null \
                | grep -P "\b(install|blacklist)\h+${mod_chk_name//-/_}\b")

            lsmod 2>/dev/null | grep -q "$mod_chk_name" && \
                modprobe -r "$mod_chk_name" 2>/dev/null; rmmod "$mod_name" 2>/dev/null

            echo "$showconfig" | grep -Pq "\binstall\h+${mod_chk_name//-/_}\h+(\/usr)?\/bin\/(true|false)\b" || \
                printf '%s\n' "install ${mod_chk_name} $(readlink -f /bin/false)" >> "$conf_file"

            echo "$showconfig" | grep -Pq "\bblacklist\h+${mod_chk_name//-/_}\b" || \
                printf '%s\n' "blacklist ${mod_chk_name}" >> "$conf_file"
        fi
    done
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

# ── network_services ──
ns = data.get("network_services", {})

ipv6 = ns.get("ipv6", {})
print(f'NS_ipv6_status={ipv6.get("status", "enabled")}')
keys = ipv6.get("disable_sysctl_keys", [])
print(f'NS_ipv6_sysctl_count={len(keys)}')
for idx, key in enumerate(keys):
    print(f'NS_ipv6_sysctl_{idx}={key}')

wireless = ns.get("wireless", {})
print(f'NS_wireless_restrict={str(wireless.get("restrict", True)).lower()}')

bluetooth = ns.get("bluetooth", {})
print(f'NS_bluetooth_package={bluetooth.get("package", "")}')
print(f'NS_bluetooth_service={bluetooth.get("service", "")}')
print(f'NS_bluetooth_restrict={str(bluetooth.get("restrict", True)).lower()}')

# ── kernel_modules ──
modules = data.get("kernel_modules", [])
print(f'KM_count={len(modules)}')
for idx, mod in enumerate(modules):
    print(f'KM_{idx}_name={mod.get("name", "")}')
    print(f'KM_{idx}_type={mod.get("type", "")}')
    print(f'KM_{idx}_restrict={str(mod.get("restrict", True)).lower()}')

# ── network_parameters ──
net_params = data.get("network_parameters", {})
print(f'NP_sysctl_conf={net_params.get("sysctl_conf_file", "/etc/sysctl.d/60-netipv4_sysctl.conf")}')
print(f'NP_sysctl_conf_ipv6={net_params.get("sysctl_conf_file_ipv6", "/etc/sysctl.d/60-netipv6_sysctl.conf")}')

for section in ["ipv4", "ipv6"]:
    params = net_params.get(section, [])
    print(f'NP_{section}_count={len(params)}')
    for idx, param in enumerate(params):
        print(f'NP_{section}_{idx}_name={param.get("name", "")}')
        print(f'NP_{section}_{idx}_value={param.get("value", "")}')
        print(f'NP_{section}_{idx}_flush={param.get("flush", "")}')
        print(f'NP_{section}_{idx}_check={param.get("check", "")}')
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

load_json_logging_and_auditing() {
    local json_file="$1"
    [ -f "$json_file" ] || { echo "ERROR: logging JSON not found: $json_file"; return 1; }

    local py_script
    py_script=$(mktemp /tmp/beetle_loader_XXXXXX.py)

    cat > "$py_script" << 'PYEOF'
import json, sys

def q(v):
    return "'" + str(v).replace("'", "'\\''") + "'"

with open(sys.argv[1]) as f:
    data = json.load(f)

jd = data.get('journald', {})
print('LJ_service='         + q(jd.get('service','')))
print('LJ_config_file='     + q(jd.get('config_file','')))
print('LJ_config_drop_dir=' + q(jd.get('config_drop_dir','')))
print('LJ_tmpfiles_config=' + q(jd.get('tmpfiles_config','')))
print('LJ_tmpfiles_source=' + q(jd.get('tmpfiles_source','')))
rp = jd.get('rotation_params', [])
print('LJ_rot_count=' + q(len(rp)))
for i,p in enumerate(rp):
    print(f'LJ_rot_{i}_key='   + q(p.get('key','')))
    print(f'LJ_rot_{i}_value=' + q(p.get('value','')))

jr = jd.get('journal_remote', {})
print('JR_package='          + q(jr.get('package','')))
print('JR_upload_svc='       + q(jr.get('upload_svc','')))
print('JR_remote_svc='       + q(jr.get('remote_svc','')))
print('JR_remote_sock='      + q(jr.get('remote_sock','')))
print('JR_upload_conf_dir='  + q(jr.get('upload_conf_dir','')))
print('JR_upload_drop_file=' + q(jr.get('upload_drop_file','')))
jr_auth = jr.get('upload_auth', {})
print('JR_server_key='   + q(jr_auth.get('server_key','')))
print('JR_server_cert='  + q(jr_auth.get('server_cert','')))
print('JR_trusted_cert=' + q(jr_auth.get('trusted_cert','')))

rs = data.get('rsyslog', {})
print('RS_package='          + q(rs.get('package','')))
print('RS_service='          + q(rs.get('service','')))
print('RS_config_file='      + q(rs.get('config_file','')))
print('RS_config_dir='       + q(rs.get('config_dir','')))
print('RS_drop_file='        + q(rs.get('drop_file','')))
print('RS_file_create_mode=' + q(rs.get('file_create_mode','')))
print('RS_remote_port='      + q(rs.get('remote_port','')))
print('RS_remote_protocol='  + q(rs.get('remote_protocol','')))
print('RS_queue_type='       + q(rs.get('queue_type','')))
print('RS_queue_size='       + q(rs.get('queue_size','')))
print('RS_resume_retry='     + q(rs.get('resume_retry','')))
print('RS_logrotate_config=' + q(rs.get('logrotate_config','')))
print('RS_logrotate_dir='    + q(rs.get('logrotate_dir','')))
rules = rs.get('logging_rules', [])
print('RS_rules_count=' + q(len(rules)))
for i,r in enumerate(rules):
    print(f'RS_{i}_name=' + q(r.get('name','')))
    print(f'RS_{i}_rule=' + q(r.get('rule','')))
    print(f'RS_{i}_dest=' + q(r.get('dest','')))

lp = data.get('logfile_permissions', {})
print('LP_search_dir=' + q(lp.get('search_dir','')))
lp_rules = lp.get('rules', [])
print('LP_rules_count=' + q(len(lp_rules)))
for i,r in enumerate(lp_rules):
    print(f'LP_{i}_match_type=' + q(r.get('match_type','')))
    print(f'LP_{i}_pattern='    + q(r.get('pattern','')))
    print(f'LP_{i}_perm_mask='  + q(r.get('perm_mask','')))
    print(f'LP_{i}_rperms='     + q(r.get('rperms','')))
    print(f'LP_{i}_owner='      + q(r.get('owner','')))
    print(f'LP_{i}_group='      + q(r.get('group','')))
    print(f'LP_{i}_fix_group='  + q(r.get('fix_group','')))
ad = data.get('auditd', {})
print('AD_service='          + q(ad.get('service','')))
print('AD_grub_config='      + q(ad.get('grub_config','')))
print('AD_grub_cmdline_key=' + q(ad.get('grub_cmdline_key','')))
pkgs = ad.get('packages', [])
print('AD_pkg_count=' + q(len(pkgs)))
for i,p in enumerate(pkgs):
    print(f'AD_pkg_{i}_name=' + q(p.get('name','')))
gp = ad.get('grub_params', [])
print('AD_grub_param_count=' + q(len(gp)))
for i,p in enumerate(gp):
    print(f'AD_grub_{i}_name='  + q(p.get('name','')))
    print(f'AD_grub_{i}_value=' + q(p.get('value','')))
ac = data.get('auditd_config', {})
print('AC_config_file=' + q(ac.get('config_file','')))
ac_params = ac.get('params', [])
print('AC_count=' + q(len(ac_params)))
for i,p in enumerate(ac_params):
    print(f'AC_{i}_name='         + q(p.get('name','')))
    print(f'AC_{i}_value='        + q(p.get('value','')))
    print(f'AC_{i}_valid_values=' + q(p.get('valid_values','')))
ar = data.get('audit_rules', {})
print('AR_rules_dir=' + q(ar.get('rules_dir','')))
groups = ar.get('rule_groups', [])
print('AR_group_count=' + q(len(groups)))
for i,g in enumerate(groups):
    print(f'AR_{i}_name=' + q(g.get('name','')))
    print(f'AR_{i}_file=' + q(g.get('file','')))
    print(f'AR_{i}_key='  + q(g.get('key','')))
    rules = g.get('rules', [])
    print(f'AR_{i}_rule_count=' + q(len(rules)))
    for j,r in enumerate(rules):
        print(f'AR_{i}_{j}_rule=' + q(r))
    paths = g.get('paths', [])
    print(f'AR_{i}_path_count=' + q(len(paths)))
    for k,p in enumerate(paths):
        print(f'AR_{i}_path_{k}=' + q(p))
print('AC_log_file_perm_mask=' + q(ac.get('log_file_perm_mask','')))
print('AC_log_dir_perm_mask='  + q(ac.get('log_dir_perm_mask','')))
print('AC_log_group='          + q(ac.get('log_group','')))
print('AC_conf_perm_mask='     + q(ac.get('conf_perm_mask','')))
print('AC_tools_perm_mask='    + q(ac.get('tools_perm_mask','')))
tools = ac.get('tools', [])
print('AC_tools_count=' + q(len(tools)))
for i,t in enumerate(tools):
    print(f'AC_tool_{i}=' + q(t))
ai = data.get('aide', {})
print('AI_db_init='           + q(ai.get('db_init','')))
print('AI_db_active='         + q(ai.get('db_active','')))
print('AI_conf_file='         + q(ai.get('conf_file','')))
print('AI_timer='             + q(ai.get('timer','')))
print('AI_service='           + q(ai.get('service','')))
print('AI_integrity_options=' + q(ai.get('integrity_options','')))
ai_pkgs = ai.get('packages', [])
print('AI_pkg_count=' + q(len(ai_pkgs)))
for i,p in enumerate(ai_pkgs):
    print(f'AI_pkg_{i}_name=' + q(p.get('name','')))
ai_tools = ai.get('audit_tools', [])
print('AI_tools_count=' + q(len(ai_tools)))
for i,t in enumerate(ai_tools):
    print(f'AI_tool_{i}=' + q(t))
PYEOF

    python3 "$py_script" "$json_file" > "$LOGGING_RAM_STORE"
    local exit_code=$?
    rm -f "$py_script"

    [ $exit_code -ne 0 ] && { echo "ERROR: failed to parse $json_file"; return 1; }
    chmod 600 "$LOGGING_RAM_STORE"
    source "$LOGGING_RAM_STORE"
}

unload_json_logging_and_auditing() {
    rm -f "$LOGGING_RAM_STORE"
    unset $(compgen -v | grep -E '^(LJ_|JR_|JP_|RS_|LP_|AD_|AC_|AR_|AI_)')
}

get_ar_group_index() {
    local target="$1"
    for ((i=0; i<AR_group_count; i++)); do
        n_var="AR_${i}_name"; [ "${!n_var}" = "$target" ] && { echo $i; return 0; }
    done
    echo -1; return 1
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

# ─────────────────────────────────────────────
# SSH: Load access_control JSON into RAM
# ─────────────────────────────────────────────

load_json_access_control() {
    local json_file="$1"

    [ -f "$json_file" ] || { echo "ERROR: JSON not found: $json_file"; return 1; }

    rm -f "$SSH_RAM_STORE"

    python3 - <<EOF > "$SSH_RAM_STORE"
import json

with open("$json_file") as f:
    data = json.load(f)


# private/public host key entries use key_name directly (not a file path)
# already handled above since entry["file"] is set in json
# if your json uses key_name as lookup instead, add:
for key_name, entry in data.get("ssh_config_file_permissions", {}).items():
    safe_key = key_name.replace("/", "_").replace("-", "_").replace(".", "_").lstrip("_")
    print(f'ACC_{safe_key}_perm_mask={entry["perm_mask"]}')
    print(f'ACC_{safe_key}_owner={entry["owner"]}')
    print(f'ACC_{safe_key}_group={entry["group"]}')

# sshd_settings
for key, val in data.get("sshd_settings", {}).items():
    safe = key.upper()
    if isinstance(val, dict):
        for field, fval in val.items():
            if isinstance(fval, list):
                joined = "|".join(str(v) for v in fval)
                print(f'SSHD_{safe}_{field.upper()}="{joined}"')
            else:
                print(f'SSHD_{safe}_{field.upper()}={fval}')

# weak lists
for list_key in ("sshd_weak_ciphers", "sshd_weak_macs", "sshd_weak_kex"):
    items = data.get(list_key, [])
    if items:
        pattern = "|".join(i.replace(".", "\\.") for i in items)
        env_key = list_key.upper() + "_PATTERN"
        print(f'{env_key}="{pattern}"')
EOF

    chmod 600 "$SSH_RAM_STORE"
    source "$SSH_RAM_STORE"
}

unload_json_access_control() {
    [ -f "$SSH_RAM_STORE" ] && shred -u "$SSH_RAM_STORE" 2>/dev/null || rm -f "$SSH_RAM_STORE"
}

unload_all() {
    unload_dpkg
    unload_json_initial_setup
    unload_json_system_maintenance
    unload_json_network
    unload_json_services
    unload_json_access_control
    unload_json_host_based_firewall
    unload_json_logging_and_auditing
    unload_severity
}

export -f load_dpkg
export -f unload_dpkg
export -f is_package_installed
export -f load_severity
export -f unload_severity
export -f is_check_enabled
export -f get_perm
export -f load_module_json
export -f unload_module_json
export -f load_dpkg unload_dpkg is_package_installed get_installed_version unset_package
export -f load_severity unload_severity is_check_enabled
export -f load_json_initial_setup unload_json_initial_setup 
export -f beetle_module_audit beetle_module_harden
export -f get_partition_idx is_partition_mounted partition_has_option
export -f load_json_system_maintenance unload_json_system_maintenance get_perm
export -f load_json_network unload_json_network get_net
export -f check_ipv6_disabled
export -f network_audit_sysctl_param
export -f network_audit_sysctl_file
export -f network_harden_sysctl_param
export -f load_json_logging_and_auditing unload_json_logging_and_auditing get_ar_group_index
export -f load_json_services unload_json_services get_svc get_svc_services is_version_ok get_svc_packages
export -f load_json_host_based_firewall unload_json_host_based_firewall get_fw
export -f load_json_access_control unload_json_access_control get_acc
export -f unload_all
export SEVERITY_RAM_STORE
export DPKG_RAM_STORE
export PERM_RAM_STORE
export SEVERITY_CONFIG_DIR
export SSH_RAM_STORE

