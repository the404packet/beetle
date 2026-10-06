# ─────────────────────────────────────────────
# Per-type RAM store paths
# ─────────────────────────────────────────────
DPKG_RAM_STORE="/dev/shm/beetle_dpkg.env"
SEVERITY_RAM_STORE="/dev/shm/beetle_severity.env"
PERM_RAM_STORE="/dev/shm/beetle_permissions.env"          # system_maintenance
SSH_RAM_STORE="/dev/shm/beetle_ssh.env"
NETWORK_RAM_STORE="/dev/shm/beetle_network.env"           # network
SERVICES_RAM_STORE="/dev/shm/beetle_services.env"         # services
FIREWALL_RAM_STORE="/dev/shm/beetle_fw_store.env"         # host_based_firewall
FW_RAM_STORE="/dev/shm/beetle_fw_store.env"                  # host_based_firewall but cooler
LOGGING_RAM_STORE="/dev/shm/beetle_logging_store.env"
INITIAL_SETUP_RAM_STORE="/dev/shm/beetle_initial_setup_store.env"

SEVERITY_CONFIG_DIR="/etc/beetle"

# Resolve bundled jq (falls back to system jq)
_BEETLE_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JQ="$_BEETLE_LIB_DIR/bin/jq"
[[ -x "$JQ" ]] || JQ="$(command -v jq)"
[[ -x "$JQ" ]] || { echo "ERROR: jq not found (bundled or system)" >&2; exit 1; }
export JQ
export DPKG_RAM_STORE SEVERITY_RAM_STORE PERM_RAM_STORE \
       NETWORK_RAM_STORE SERVICES_RAM_STORE ACCESS_RAM_STORE FW_RAM_STORE FIREWALL_RAM_STORE \
       LOGGING_RAM_STORE SSH_RAM_STORE INITIAL_SETUP_RAM_STORE

_clean_ram_store() {
    local path="$1"
    [ -e "$path" ] || return 0
    rm -f "$path" 2>/dev/null || \
        sudo -n rm -f "$path" 2>/dev/null || \
        : > "$path" 2>/dev/null || \
        true
}

load_dpkg() {
    _clean_ram_store "$DPKG_RAM_STORE"

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
    [ -f "$DPKG_RAM_STORE" ] && shred -u "$DPKG_RAM_STORE" 2>/dev/null || _clean_ram_store "$DPKG_RAM_STORE"
}

is_package_installed() {
    local pkg="$1"
    local key="PKG_${pkg//[^a-zA-Z0-9_]/_}"

    if [ -z "${!key}" ] && [ -f "$DPKG_RAM_STORE" ]; then
        source "$DPKG_RAM_STORE"
    fi  

    [ "${!key}" = "installed" ]
}

require_present() {
    local kind="$1" target="$2"
    case "$kind" in
        file)    [ -e "$target" ] && return 0 ;;
        dir)     [ -d "$target" ] && return 0 ;;
        pkg)     dpkg-query -W -f='${Status}' "$target" 2>/dev/null \
                     | grep -q "install ok installed" && return 0 ;;
        service) systemctl list-unit-files "$target" 2>/dev/null \
                     | grep -q "^${target}" && return 0 ;;
        cmd)     command -v "$target" >/dev/null 2>&1 && return 0 ;;
        *)       [ -e "$target" ] && return 0 ;;
    esac
    echo -e "\e[31mNOT HARDENED\e[0m"
    exit 0
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
    local target_level="${1,,}"
    _clean_ram_store "$SEVERITY_RAM_STORE"

    local levels=("basic")
    [[ "$target_level" == "moderate" ]] && levels=("basic" "moderate")
    [[ "$target_level" == "strict"   ]] && levels=("basic" "moderate" "strict")

    # Collect existing severity files
    local files=()
    for level in "${levels[@]}"; do
        local file="$SEVERITY_CONFIG_DIR/severity_${level}.json"
        [[ -f "$file" ]] && files+=("$file")
    done

    if [[ ${#files[@]} -eq 0 ]]; then
        chmod 600 "$SEVERITY_RAM_STORE" 2>/dev/null || true
        return 0
    fi

    # Merge all files (later overrides earlier), emit SEV_ vars
    "$JQ" -r '
        reduce .[] as $item ({}; . + $item) |
        to_entries[] |
        (.key | gsub("/"; "__") | gsub("-"; "_") | gsub("\\."; "_")) as $k |
        "SEV_\($k)=\(if .value then "true" else "false" end)"
    ' --slurp "${files[@]}" > "$SEVERITY_RAM_STORE" 2>/dev/null

    chmod 600 "$SEVERITY_RAM_STORE"
    source "$SEVERITY_RAM_STORE"
}

unload_severity() {
    [ -f "$SEVERITY_RAM_STORE" ] && shred -u "$SEVERITY_RAM_STORE" 2>/dev/null || _clean_ram_store "$SEVERITY_RAM_STORE"
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

    # Must normalize the same way as load_severity
    # (see jq normkey definition)
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

    _clean_ram_store "$INITIAL_SETUP_RAM_STORE"

    # ── apparmor ──
    "$JQ" -r '
        (.apparmor // {}) as $aa |
        "AA_grub_config=\($aa.grub_config // "" | @sh)",
        "AA_grub_cfg=\($aa.grub_cfg // "" | @sh)",
        "AA_grub_cmdline_key=\($aa.grub_cmdline_key // "" | @sh)",
        "AA_profiles_dir=\($aa.profiles_dir // "" | @sh)",
        "AA_enforce_mode=\($aa.enforce_mode // "" | @sh)",
        "AA_complain_mode=\($aa.complain_mode // "" | @sh)",
        (($aa.packages // []) | length) as $n |
        "AA_pkg_count=\($n | @sh)",
        (($aa.packages // []) | to_entries[] |
            "AA_pkg_\(.key)_name=\(.value.name // "" | @sh)"),
        (($aa.grub_params // []) | length) as $gp |
        "AA_grub_param_count=\($gp | @sh)",
        (($aa.grub_params // []) | to_entries[] |
            "AA_grub_\(.key)_name=\(.value.name // "" | @sh)",
            "AA_grub_\(.key)_value=\(.value.value // "" | @sh)")
    ' "$json_file" >> "$INITIAL_SETUP_RAM_STORE"

    # ── filesystem_modules ──
    "$JQ" -r '
        (.filesystem_modules // {}) as $fm |
        "FM_modprobe_dir=\($fm.modprobe_dir // "" | @sh)",
        (($fm.modules // []) | length) as $n |
        "FM_count=\($n | @sh)",
        (($fm.modules // []) | to_entries[] |
            "FM_\(.key)_name=\(.value.name // "" | @sh)",
            "FM_\(.key)_type=\(.value.type // "" | @sh)")
    ' "$json_file" >> "$INITIAL_SETUP_RAM_STORE"

    # ── filesystem_partitions ──
    "$JQ" -r '
        (.filesystem_partitions // {}) as $fp |
        (($fp.partitions // []) | length) as $n |
        "FP_count=\($n | @sh)",
        (($fp.partitions // []) | to_entries[] |
            (.key) as $i |
            (.value) as $p |
            ($p.mount // "") as $mount |
            ($mount | gsub("/"; "_") | sub("^_"; "")) as $mk |
            "FP_\($i)_mount=\($mount | @sh)",
            "FP_\($i)_mount_key=\($mk | @sh)",
            "FP_\($i)_required=\(if ($p.required // false) then "true" else "false" end | @sh)",
            "FP_\($i)_systemd_unit=\(($p.systemd_unit // "") | @sh)",
            (($p.options // []) | length) as $on |
            "FP_\($i)_opt_count=\($on | @sh)",
            (($p.options // []) | to_entries[] | "FP_\($i)_opt_\(.key)=\(.value | @sh)"),
            "FP_idx_\($mk)=\($i | @sh)")
    ' "$json_file" >> "$INITIAL_SETUP_RAM_STORE"

    # ── bootloader ──
    "$JQ" -r '
        (.bootloader // {}) as $bl |
        "BL_grub_cfg=\($bl.grub_cfg // "/boot/grub/grub.cfg" | @sh)",
        "BL_grub_config=\($bl.grub_config // "/etc/default/grub" | @sh)",
        "BL_grub_custom_dir=\($bl.grub_custom_dir // "/etc/grub.d" | @sh)",
        "BL_grub_custom_file=\($bl.grub_custom_file // "/etc/grub.d/40_custom" | @sh)",
        "BL_superuser=\($bl.superuser // "grub_admin" | @sh)",
        "BL_perm_mask=\($bl.perm_mask // "0177" | @sh)",
        "BL_owner=\($bl.owner // "root" | @sh)",
        "BL_group=\($bl.group // "root" | @sh)"
    ' "$json_file" >> "$INITIAL_SETUP_RAM_STORE"

    # ── process_hardening ──
    "$JQ" -r '
        (.process_hardening // {}) as $ph |
        "PH_sysctl_conf=\($ph.sysctl_conf_file // "/etc/sysctl.d/60-kernel_sysctl.conf" | @sh)",
        "PH_coredump_conf=\($ph.coredump_conf // "/etc/systemd/coredump.conf" | @sh)",
        "PH_limits_conf=\($ph.limits_conf // "/etc/security/limits.conf" | @sh)",
        (($ph.kernel_params // []) | length) as $n |
        "PH_kparam_count=\($n | @sh)",
        (($ph.kernel_params // []) | to_entries[] |
            "PH_kparam_\(.key)_name=\(.value.name // "" | @sh)",
            "PH_kparam_\(.key)_value=\(.value.value // "" | @sh)"),
        (($ph.apport // {}) as $ap |
            "PH_apport_config=\($ap.config_file // "/etc/default/apport" | @sh)",
            "PH_apport_service=\($ap.service // "apport.service" | @sh)")
    ' "$json_file" >> "$INITIAL_SETUP_RAM_STORE"

    # ── warning_banners ──
    "$JQ" -r '
        (.warning_banners // {}) as $wb |
        (($wb.banner_files // []) | length) as $n |
        "WB_count=\($n | @sh)",
        "WB_os_info_pattern=\($wb.os_info_pattern // "(\\\\v|\\\\r|\\\\m|\\\\s)" | @sh)",
        (($wb.banner_files // []) | to_entries[] |
            "WB_\(.key)_path=\(.value.path // "" | @sh)",
            "WB_\(.key)_required=\(if (.value.required // false) then "true" else "false" end | @sh)",
            "WB_\(.key)_perm_mask=\(.value.perm_mask // "0133" | @sh)",
            "WB_\(.key)_owner=\(.value.owner // "root" | @sh)",
            "WB_\(.key)_group=\(.value.group // "root" | @sh)")
    ' "$json_file" >> "$INITIAL_SETUP_RAM_STORE"

    # ── gdm ──
    "$JQ" -r '
        (.gdm // {}) as $gd |
        "GD_package=\($gd.package // "" | @sh)",
        "GD_profile_dir=\($gd.profile_dir // "" | @sh)",
        "GD_profile_file=\($gd.profile_file // "" | @sh)",
        "GD_db_dir=\($gd.db_dir // "" | @sh)",
        "GD_locks_dir=\($gd.locks_dir // "" | @sh)",
        "GD_gdm_db_dir=\($gd.gdm_db_dir // "" | @sh)",
        "GD_banner_file=\($gd.banner_file // "" | @sh)",
        "GD_login_screen_file=\($gd.login_screen_file // "" | @sh)",
        "GD_screensaver_file=\($gd.screensaver_file // "" | @sh)",
        "GD_screensaver_lock=\($gd.screensaver_lock // "" | @sh)",
        "GD_automount_file=\($gd.automount_file // "" | @sh)",
        "GD_automount_lock=\($gd.automount_lock // "" | @sh)",
        "GD_autorun_file=\($gd.autorun_file // "" | @sh)",
        "GD_autorun_lock=\($gd.autorun_lock // "" | @sh)",
        "GD_banner_text=\($gd.banner_text // "" | @sh)",
        "GD_idle_delay=\($gd.idle_delay // 900 | @sh)",
        "GD_lock_delay=\($gd.lock_delay // 5 | @sh)",
        (($gd.xdmcp_configs // []) | length) as $n |
        "GD_xdmcp_count=\($n | @sh)",
        (($gd.xdmcp_configs // []) | to_entries[] | "GD_xdmcp_\(.key)=\(.value | @sh)")
    ' "$json_file" >> "$INITIAL_SETUP_RAM_STORE"

    # ── package_manager ──
    "$JQ" -r '
        (.package_manager // {}) as $pm |
        "PM_sources_file=\($pm.sources_file // "/etc/apt/sources.list" | @sh)",
        (($pm.gpg_dirs // []) | length) as $n |
        "PM_gpg_dir_count=\($n | @sh)",
        (($pm.gpg_dirs // []) | to_entries[] | "PM_gpg_dir_\(.key)=\(.value | @sh)"),
        (($pm.gpg_extensions // []) | length) as $n2 |
        "PM_gpg_ext_count=\($n2 | @sh)",
        (($pm.gpg_extensions // []) | to_entries[] | "PM_gpg_ext_\(.key)=\(.value | @sh)"),
        (($pm.recommended_repos // []) | length) as $n3 |
        "PM_repo_count=\($n3 | @sh)",
        (($pm.recommended_repos // []) | to_entries[] | "PM_repo_\(.key)=\(.value | @sh)"),
        (($pm.recommended_gpg_keys // []) | length) as $n4 |
        "PM_gpg_key_count=\($n4 | @sh)",
        (($pm.recommended_gpg_keys // []) | to_entries[] |
            "PM_gpg_key_\(.key)_name=\(.value.name // "" | @sh)",
            "PM_gpg_key_\(.key)_keyid=\(.value.keyid // "" | @sh)",
            "PM_gpg_key_\(.key)_keyserver=\(.value.keyserver // "" | @sh)")
    ' "$json_file" >> "$INITIAL_SETUP_RAM_STORE"

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
    _clean_ram_store "$INITIAL_SETUP_RAM_STORE"
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

            # Persistent block must be present
            echo "$showconfig" | grep -Pq "\binstall\h+${mod_chk_name//-/_}\h+\S*/(true|false)\b" || return 1
            echo "$showconfig" | grep -Pq "\bblacklist\h+${mod_chk_name//-/_}\b" || return 1

            # Real test: modprobe must not plan to insmod it
            if modprobe --dry-run "$mod_chk_name" 2>/dev/null | grep -q "insmod"; then
                return 1
            fi
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

            echo "$showconfig" | grep -Pq "\binstall\h+${mod_chk_name//-/_}\h+\S*/(true|false)\b" || \
                printf '%s\n' "install ${mod_chk_name} /bin/false" >> "$conf_file"

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
    _clean_ram_store "$NETWORK_RAM_STORE"

    "$JQ" -r '
        # ── network_services ──
        (.network_services.ipv6.status // "enabled") as $ipv6_status |
        (.network_services.ipv6.disable_sysctl_keys // []) as $ipv6_keys |
        (.network_services.wireless.restrict // true) as $wireless_restrict |
        (.network_services.bluetooth.package // "") as $bt_pkg |
        (.network_services.bluetooth.service // "") as $bt_svc |
        (.network_services.bluetooth.restrict // true) as $bt_restrict |

        "NS_ipv6_status=\($ipv6_status)",
        "NS_ipv6_sysctl_count=\($ipv6_keys | length)",
        ($ipv6_keys | to_entries[] | "NS_ipv6_sysctl_\(.key)=\(.value)"),
        "NS_wireless_restrict=\($wireless_restrict)",
        "NS_bluetooth_package=\($bt_pkg)",
        "NS_bluetooth_service=\($bt_svc)",
        "NS_bluetooth_restrict=\($bt_restrict)",

        # ── kernel_modules ──
        (.kernel_modules // []) as $mods |
        "KM_count=\($mods | length)",
        ($mods | to_entries[] |
            "KM_\(.key)_name=\(.value.name // "")",
            "KM_\(.key)_type=\(.value.type // "")",
            "KM_\(.key)_restrict=\(if (.value.restrict // true) then "true" else "false" end)"
        ),

        # ── network_parameters ──
        (.network_parameters.sysctl_conf_file // "/etc/sysctl.d/60-netipv4_sysctl.conf") as $scf4 |
        (.network_parameters.sysctl_conf_file_ipv6 // "/etc/sysctl.d/60-netipv6_sysctl.conf") as $scf6 |
        "NP_sysctl_conf=\($scf4)",
        "NP_sysctl_conf_ipv6=\($scf6)",

        (.network_parameters.ipv4 // []) as $p4 |
        "NP_ipv4_count=\($p4 | length)",
        ($p4 | to_entries[] |
            "NP_ipv4_\(.key)_name=\(.value.name // "")",
            "NP_ipv4_\(.key)_value=\(.value.value // "")",
            "NP_ipv4_\(.key)_flush=\(.value.flush // "")",
            "NP_ipv4_\(.key)_check=\(.value.check // "")"
        ),

        (.network_parameters.ipv6 // []) as $p6 |
        "NP_ipv6_count=\($p6 | length)",
        ($p6 | to_entries[] |
            "NP_ipv6_\(.key)_name=\(.value.name // "")",
            "NP_ipv6_\(.key)_value=\(.value.value // "")",
            "NP_ipv6_\(.key)_flush=\(.value.flush // "")",
            "NP_ipv6_\(.key)_check=\(.value.check // "")"
        )
    ' "$json_file" > "$NETWORK_RAM_STORE"

    chmod 600 "$NETWORK_RAM_STORE"
    source "$NETWORK_RAM_STORE"
}

unload_json_network() {
    [ -f "$NETWORK_RAM_STORE" ] && shred -u "$NETWORK_RAM_STORE" 2>/dev/null || _clean_ram_store "$NETWORK_RAM_STORE"
}

get_net() {
    local name="$1" field="$2"
    local key; key=$(echo "$name" | sed 's|/|_|g; s|-|_|g; s|\.|_|g; s|^_||')
    local var="NET_${key}_${field}"
    echo "${!var}"
}

unload_json_network() {
    [ -f "$NETWORK_RAM_STORE" ] && shred -u "$NETWORK_RAM_STORE" 2>/dev/null || _clean_ram_store "$NETWORK_RAM_STORE"
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
live_package_installed() {
    local pkg="$1"
    dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "install ok installed"
}

load_json_services() {
    local json_file="$1"
    [ -f "$json_file" ] || { echo "ERROR: JSON not found: $json_file"; return 1; }
    _clean_ram_store "$SERVICES_RAM_STORE"

    "$JQ" -r '
        def normkey: gsub("/"; "_") | gsub("-"; "_") | gsub("\\."; "_") | sub("^_"; "");

        # ── server_services + client_services ──
        (["server_services", "client_services"] | .[]) as $section |
        (. as $root |
         ($root[$section] // {}) | to_entries[] |
            (.key | normkey) as $cat_key |
            (.value | length) as $pkg_count |
            "SS_\($cat_key)_pkg_count=\($pkg_count)",
            (.value | to_entries | to_entries[] |
                (.key) as $pkg_idx |
                (.value.key) as $pkg_name |
                (.value.value) as $pkg_fields |
                ($pkg_name | normkey) as $pkg_key |
                "SS_\($cat_key)_pkg_\($pkg_idx)=\($pkg_name)",
                "SS_\($cat_key)_\($pkg_key)_restrict=\(if ($pkg_fields.restrict // true) then "true" else "false" end)",
                "SS_\($cat_key)_\($pkg_key)_version=\($pkg_fields.version // "null" | if . == null then "null" else . end)",
                "SS_\($cat_key)_\($pkg_key)_svc_count=\(($pkg_fields.services // []) | length)",
                (($pkg_fields.services // []) | to_entries[] |
                    "SS_\($cat_key)_\($pkg_key)_svc_\(.key)=\(.value)"
                )
            )
        ),

        # ── job_service ──
        (.job_service.daemons // []) as $js_daemons |
        "JS_daemon_count=\($js_daemons | length)",
        "JS_daemon_any_required=\(if ($js_daemons | any(.required // false)) then "true" else "false" end)",
        ($js_daemons | to_entries[] |
            (.key) as $i |
            (.value) as $d |
            ($d.name // "" | gsub("-"; "_") | gsub("\\."; "_")) as $name_key |
            "JS_daemon_\($i)_name=\($d.name // "")",
            "JS_daemon_\($i)_package=\($d.package // "")",
            "JS_daemon_\($i)_service=\($d.service // "")",
            "JS_daemon_\($i)_required=\(if ($d.required // false) then "true" else "false" end)",
            "JS_daemon_\($i)_check_if_installed=\(if ($d.check_if_installed // false) then "true" else "false" end)",
            "JS_daemon_name_\($name_key)_idx=\($i)"
        ),

        (.job_service.cron_dirs // []) as $cron_dirs |
        "JS_cron_dir_count=\($cron_dirs | length)",
        ($cron_dirs | to_entries[] |
            "JS_cron_dir_\(.key)_file=\(.value.file // "")",
            "JS_cron_dir_\(.key)_mode=\(.value.mode // "")",
            "JS_cron_dir_\(.key)_owner=\(.value.owner // "")",
            "JS_cron_dir_\(.key)_group=\(.value.group // "")"
        ),

        (["cron_access", "at_access"] | .[]) as $sk |
        (.job_service[$sk] // {}) as $s |
        "JS_\($sk)_allow_file=\($s.allow_file // "")",
        "JS_\($sk)_deny_file=\($s.deny_file // "")",
        "JS_\($sk)_mode=\($s.mode // "")",
        "JS_\($sk)_owner=\($s.owner // "")",
        "JS_\($sk)_group_count=\(($s.groups // []) | length)",
        (($s.groups // []) | to_entries[] | "JS_\($sk)_group_\(.key)=\(.value)"),

        # ── time_sync ──
        (.time_sync.default // "") as $ts_default |
        (.time_sync.daemons // []) as $ts_daemons |
        "TS_default=\($ts_default)",
        "TS_daemon_count=\($ts_daemons | length)",
        ($ts_daemons | to_entries[] |
            (.key) as $i |
            (.value) as $d |
            "TS_daemon_\($i)_name=\($d.name // "")",
            "TS_daemon_\($i)_package=\($d.package // "")",
            "TS_daemon_\($i)_service=\($d.service // "")",
            "TS_daemon_\($i)_config_file=\($d.config_file // "")",
            "TS_daemon_\($i)_config_dir=\($d.config_dir // "")",
            "TS_daemon_\($i)_run_as_user=\($d.run_as_user // "")",
            "TS_daemon_\($i)_ntp_count=\(($d.ntp_servers // []) | length)",
            (($d.ntp_servers // []) | to_entries[] | "TS_daemon_\($i)_ntp_\(.key)=\(.value)"),
            "TS_daemon_\($i)_fallback_count=\(($d.fallback_servers // []) | length)",
            (($d.fallback_servers // []) | to_entries[] | "TS_daemon_\($i)_fallback_\(.key)=\(.value)")
        )
    ' "$json_file" > "$SERVICES_RAM_STORE"

    chmod 600 "$SERVICES_RAM_STORE"
    source "$SERVICES_RAM_STORE"
}

unload_json_services() {
    [ -f "$SERVICES_RAM_STORE" ] && shred -u "$SERVICES_RAM_STORE" 2>/dev/null || _clean_ram_store "$SERVICES_RAM_STORE"
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
    _clean_ram_store "$FIREWALL_RAM_STORE"

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
    [ -f "$FIREWALL_RAM_STORE" ] && shred -u "$FIREWALL_RAM_STORE" 2>/dev/null || _clean_ram_store "$FIREWALL_RAM_STORE"
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

    _clean_ram_store "$PERM_RAM_STORE"

    "$JQ" -r '
        . as $root |
        def normkey: gsub("/"; "_") | gsub("-"; "_") | gsub("\\."; "_") | sub("^_"; "");

        # ── system_file_permissions ──
        ($root.system_file_permissions // []) | .[] |
            (.file | normkey) as $key |
            (.mode) as $mode |
            (.owner) as $owner |
            ((.group // "") | if . == "root/shadow" then "shadow" else . end) as $group |
            "PERM_\($key)_mode=\($mode)",
            "PERM_\($key)_owner=\($owner)",
            "PERM_\($key)_group=\($group)",

        # ── suid_sgid.known_risky ──
        ($root.suid_sgid.known_risky // []) as $risky |
        "SS_count=\($risky | length | @sh)",
        ($risky | to_entries[] |
            "SS_\(.key)_name=\(.value.name // "" | @sh)",
            "SS_\(.key)_path=\(.value.path // "" | @sh)",
            "SS_\(.key)_risk=\(.value.risk // "" | @sh)"
        )
    ' "$json_file" > "$PERM_RAM_STORE"

    chmod 600 "$PERM_RAM_STORE"
    source "$PERM_RAM_STORE"
}

unload_json_system_maintenance() {
    [ -f "$PERM_RAM_STORE" ] && shred -u "$PERM_RAM_STORE" 2>/dev/null || _clean_ram_store "$PERM_RAM_STORE"
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

    _clean_ram_store "$LOGGING_RAM_STORE"

    "$JQ" -r '
        . as $root |

        # ── preferred logging system ──
        "LJ_preferred_logging_system=\($root.logging_system // "journald" | @sh)",

        # ── journald ──
        ($root.journald // {}) as $jd |
        "LJ_service=\($jd.service // "" | @sh)",
        "LJ_config_file=\($jd.config_file // "" | @sh)",
        "LJ_config_drop_dir=\($jd.config_drop_dir // "" | @sh)",
        "LJ_tmpfiles_config=\($jd.tmpfiles_config // "" | @sh)",
        "LJ_tmpfiles_source=\($jd.tmpfiles_source // "" | @sh)",
        (($jd.rotation_params // []) | length) as $rot_n |
        "LJ_rot_count=\($rot_n | @sh)",
        (($jd.rotation_params // []) | to_entries[] |
            "LJ_rot_\(.key)_key=\(.value.key // "" | @sh)",
            "LJ_rot_\(.key)_value=\(.value.value // "" | @sh)"
        ),

        # ── journal_remote ──
        ($root.journald.journal_remote // $root.journal_remote // {}) as $jr |
        "JR_package=\($jr.package // "" | @sh)",
        "JR_upload_svc=\($jr.upload_svc // "" | @sh)",
        "JR_remote_svc=\($jr.remote_svc // "" | @sh)",
        "JR_remote_sock=\($jr.remote_sock // "" | @sh)",
        "JR_upload_conf_dir=\($jr.upload_conf_dir // "" | @sh)",
        "JR_upload_drop_file=\($jr.upload_drop_file // "" | @sh)",
        ($jr.upload_auth // {}) as $jra |
        "JR_server_key=\($jra.server_key // "" | @sh)",
        "JR_server_cert=\($jra.server_cert // "" | @sh)",
        "JR_trusted_cert=\($jra.trusted_cert // "" | @sh)",

        # ── rsyslog ──
        ($root.rsyslog // {}) as $rs |
        "RS_package=\($rs.package // "" | @sh)",
        "RS_service=\($rs.service // "" | @sh)",
        "RS_config_file=\($rs.config_file // "" | @sh)",
        "RS_config_dir=\($rs.config_dir // "" | @sh)",
        "RS_drop_file=\($rs.drop_file // "" | @sh)",
        "RS_file_create_mode=\($rs.file_create_mode // "" | @sh)",
        "RS_remote_port=\($rs.remote_port // "" | @sh)",
        "RS_remote_protocol=\($rs.remote_protocol // "" | @sh)",
        "RS_queue_type=\($rs.queue_type // "" | @sh)",
        "RS_queue_size=\($rs.queue_size // "" | @sh)",
        "RS_resume_retry=\($rs.resume_retry // "" | @sh)",
        "RS_logrotate_config=\($rs.logrotate_config // "" | @sh)",
        "RS_logrotate_dir=\($rs.logrotate_dir // "" | @sh)",
        (($rs.logging_rules // []) | length) as $rs_n |
        "RS_rules_count=\($rs_n | @sh)",
        (($rs.logging_rules // []) | to_entries[] |
            "RS_\(.key)_name=\(.value.name // "" | @sh)",
            "RS_\(.key)_rule=\(.value.rule // "" | @sh)",
            "RS_\(.key)_dest=\(.value.dest // "" | @sh)"
        ),

        # ── logfile_permissions ──
        ($root.logfile_permissions // {}) as $lp |
        "LP_search_dir=\($lp.search_dir // "" | @sh)",
        (($lp.rules // []) | length) as $lp_n |
        "LP_rules_count=\($lp_n | @sh)",
        (($lp.rules // []) | to_entries[] |
            "LP_\(.key)_match_type=\(.value.match_type // "" | @sh)",
            "LP_\(.key)_pattern=\(.value.pattern // "" | @sh)",
            "LP_\(.key)_perm_mask=\(.value.perm_mask // "" | @sh)",
            "LP_\(.key)_rperms=\(.value.rperms // "" | @sh)",
            "LP_\(.key)_owner=\(.value.owner // "" | @sh)",
            "LP_\(.key)_group=\(.value.group // "" | @sh)",
            "LP_\(.key)_fix_group=\(.value.fix_group // "" | @sh)"
        ),

        # ── auditd ──
        ($root.auditd // {}) as $ad |
        "AD_service=\($ad.service // "" | @sh)",
        "AD_grub_config=\($ad.grub_config // "" | @sh)",
        "AD_grub_cmdline_key=\($ad.grub_cmdline_key // "" | @sh)",
        (($ad.packages // []) | length) as $ad_pkg_n |
        "AD_pkg_count=\($ad_pkg_n | @sh)",
        (($ad.packages // []) | to_entries[] |
            "AD_pkg_\(.key)_name=\(.value.name // "" | @sh)"
        ),
        (($ad.grub_params // []) | length) as $ad_gp_n |
        "AD_grub_param_count=\($ad.grub_param_count // $ad_gp_n | @sh)",
        (($ad.grub_params // []) | to_entries[] |
            "AD_grub_\(.key)_name=\(.value.name // "" | @sh)",
            "AD_grub_\(.key)_value=\(.value.value // "" | @sh)"
        ),

        # ── auditd_config ──
        ($root.auditd_config // {}) as $ac |
        "AC_config_file=\($ac.config_file // "" | @sh)",
        (($ac.params // []) | length) as $ac_n |
        "AC_count=\($ac_n | @sh)",
        (($ac.params // []) | to_entries[] |
            "AC_\(.key)_name=\(.value.name // "" | @sh)",
            "AC_\(.key)_value=\(.value.value // "" | @sh)",
            "AC_\(.key)_valid_values=\(.value.valid_values // "" | @sh)"
        ),

        # ── audit_rules ──
        ($root.audit_rules // {}) as $ar |
        "AR_rules_dir=\($ar.rules_dir // "" | @sh)",
        (($ar.rule_groups // []) | length) as $ar_n |
        "AR_group_count=\($ar_n | @sh)",
        (($ar.rule_groups // []) | to_entries[] |
            (.key) as $i |
            (.value) as $g |
            "AR_\($i)_name=\($g.name // "" | @sh)",
            "AR_\($i)_file=\($g.file // "" | @sh)",
            "AR_\($i)_key=\($g.key // "" | @sh)",
            "AR_\($i)_rule_count=\(($g.rules // []) | length | @sh)",
            (($g.rules // []) | to_entries[] | "AR_\($i)_\(.key)_rule=\(.value | @sh)"),
            "AR_\($i)_path_count=\(($g.paths // []) | length | @sh)",
            (($g.paths // []) | to_entries[] | "AR_\($i)_path_\(.key)=\(.value | @sh)")
        ),

        # ── more auditd_config fields (perm masks, tools) ──
        "AC_log_file_perm_mask=\($ac.log_file_perm_mask // "" | @sh)",
        "AC_log_dir_perm_mask=\($ac.log_dir_perm_mask // "" | @sh)",
        "AC_log_group=\($ac.log_group // "" | @sh)",
        "AC_conf_perm_mask=\($ac.conf_perm_mask // "" | @sh)",
        "AC_tools_perm_mask=\($ac.tools_perm_mask // "" | @sh)",
        (($ac.tools // []) | length) as $ac_tools_n |
        "AC_tools_count=\($ac_tools_n | @sh)",
        (($ac.tools // []) | to_entries[] | "AC_tool_\(.key)=\(.value | @sh)"),

        # ── aide ──
        ($root.aide // {}) as $ai |
        "AI_db_init=\($ai.db_init // "" | @sh)",
        "AI_db_active=\($ai.db_active // "" | @sh)",
        "AI_conf_file=\($ai.conf_file // "" | @sh)",
        "AI_timer=\($ai.timer // "" | @sh)",
        "AI_service=\($ai.service // "" | @sh)",
        "AI_integrity_options=\($ai.integrity_options // "" | @sh)",
        (($ai.packages // []) | length) as $ai_pkg_n |
        "AI_pkg_count=\($ai_pkg_n | @sh)",
        (($ai.packages // []) | to_entries[] |
            "AI_pkg_\(.key)_name=\(.value.name // "" | @sh)"
        ),
        (($ai.audit_tools // []) | length) as $ai_tools_n |
        "AI_tools_count=\($ai_tools_n | @sh)",
        (($ai.audit_tools // []) | to_entries[] | "AI_tool_\(.key)=\(.value | @sh)")
    ' "$json_file" > "$LOGGING_RAM_STORE"

    chmod 600 "$LOGGING_RAM_STORE"
    source "$LOGGING_RAM_STORE"
}

unload_json_logging_and_auditing() {
    _clean_ram_store "$LOGGING_RAM_STORE"
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

    _clean_ram_store "$SSH_RAM_STORE"

    # ── ssh_config_file_permissions ──
    "$JQ" -r '
        def normkey: gsub("/"; "_") | gsub("-"; "_") | gsub("\\."; "_") | sub("^_"; "");
        (.ssh_config_file_permissions // {}) | to_entries[] |
            (.key | normkey) as $k |
            "ACC_\($k)_perm_mask=\(.value.perm_mask // "")",
            "ACC_\($k)_owner=\(.value.owner // "")",
            "ACC_\($k)_group=\(.value.group // "")"
    ' "$json_file" >> "$SSH_RAM_STORE"

    # ── sshd_settings ──
    "$JQ" -r '
        (.sshd_settings // {}) | to_entries[] |
            (.key | ascii_upcase) as $setting |
            (.value | to_entries[] |
                (.key | ascii_upcase) as $field |
                if (.value | type) == "array" then
                    "SSHD_\($setting)_\($field)=\"\(.value | map(tostring) | join("|"))\""
                else
                    "SSHD_\($setting)_\($field)=\(.value)"
                end
            )
    ' "$json_file" >> "$SSH_RAM_STORE"

    # ── weak lists ──
    "$JQ" -r '
        (["sshd_weak_ciphers", "sshd_weak_macs", "sshd_weak_kex"] | .[]) as $k |
        (.[$k] // []) as $items |
        if ($items | length) > 0 then
            (($k | ascii_upcase) + "_PATTERN") as $var |
            "\($var)=\"\($items | map(gsub("\\."; "\\\\.")) | join("|"))\""
        else empty end
    ' "$json_file" >> "$SSH_RAM_STORE"

    # ── sudo_settings ──
    "$JQ" -r '
        (.sudo_settings // {}) | to_entries[] |
            (.key | ascii_upcase) as $setting |
            (.value | to_entries[] |
                (.key | ascii_upcase) as $field |
                "SUDO_\($setting)_\($field)=\(.value)"
            )
    ' "$json_file" >> "$SSH_RAM_STORE"

    # ── pam_settings ──
    "$JQ" -r '
        (.pam_settings // {}) | to_entries[] |
            (.key | ascii_upcase) as $section |
            (.value | to_entries[] |
                (.key | ascii_upcase) as $field |
                "PAM_\($section)_\($field)=\(.value)"
            )
    ' "$json_file" >> "$SSH_RAM_STORE"

    # ── login_defs ──
    "$JQ" -r '
        (.login_defs // {}) as $ld |
        "LD_file=\($ld.file // "/etc/login.defs")",
        "LD_pass_max_days_max=\($ld.pass_max_days.max // 365)",
        "LD_pass_min_days_min=\($ld.pass_min_days.min // 1)",
        "LD_pass_warn_age_min=\($ld.pass_warn_age.min // 7)",
        "LD_encrypt_method_allowed=\"\(($ld.encrypt_method.allowed // ["SHA512","YESCRYPT"]) | join("|"))\"",
        "LD_inactive_max=\($ld.inactive.max // 45)"
    ' "$json_file" >> "$SSH_RAM_STORE"

    # ── user_env ──
    "$JQ" -r '
        (.user_env // {}) as $ue |
        "UE_tmout_max=\($ue.tmout.max // 900)",
        "UE_tmout_profile_d_file=\($ue.tmout.profile_d_file // "/etc/profile.d/50-systemwide_tmout.sh")",
        "UE_umask_value=\($ue.umask.value // "027")",
        "UE_umask_profile_d_file=\($ue.umask.profile_d_file // "/etc/profile.d/50-systemwide_umask.sh")",
        "UE_root_umask_file_count=\(($ue.root_umask.files // ["/root/.bash_profile","/root/.bashrc"]) | length)",
        (($ue.root_umask.files // ["/root/.bash_profile","/root/.bashrc"]) | to_entries[] |
            "UE_root_umask_file_\(.key)=\(.value)")
    ' "$json_file" >> "$SSH_RAM_STORE"

    chmod 600 "$SSH_RAM_STORE"
    source "$SSH_RAM_STORE"
}

unload_json_access_control() {
    [ -f "$SSH_RAM_STORE" ] && shred -u "$SSH_RAM_STORE" 2>/dev/null || _clean_ram_store "$SSH_RAM_STORE"
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
export -f require_present
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
export -f live_package_installed
export -f _clean_ram_store
export SEVERITY_RAM_STORE
export DPKG_RAM_STORE
export PERM_RAM_STORE
export SEVERITY_CONFIG_DIR
export SSH_RAM_STORE
export FW_RAM_STORE

