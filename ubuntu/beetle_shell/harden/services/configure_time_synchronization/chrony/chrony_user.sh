#!/usr/bin/env bash

NAME="ensure chrony is running as user _chrony"

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

[ -f "$DPKG_RAM_STORE" ] && source "$DPKG_RAM_STORE"
[ -f "$SERVICES_RAM_STORE" ] && source "$SERVICES_RAM_STORE"

export DEBIAN_FRONTEND=noninteractive

daemon_count="${TS_daemon_count:-0}"
default_name="${TS_default:-}"

chrony_idx=""
other_active=""
chrony_active=false
for ((i=0; i<daemon_count; i++)); do
    name_var="TS_daemon_${i}_name"
    svc_var="TS_daemon_${i}_service"
    name="${!name_var}"
    svc="${!svc_var}"
    [ -z "$svc" ] && continue

    is_active=false
    systemctl is-active "$svc" >/dev/null 2>&1 && is_active=true

    if [ "$name" == "chrony" ]; then
        chrony_idx="$i"
        $is_active && chrony_active=true
        continue
    fi

    $is_active && other_active="$name"
done

if [ -z "$chrony_idx" ]; then
    echo -e "${GREEN}SUCCESS${RESET}"
    exit 0
fi

if [ -n "$other_active" ]; then
    echo -e "${GREEN}SUCCESS${RESET}"
    exit 0
fi

# Chrony not active:
#   - If chrony is NOT the default → no-op
#   - If chrony IS the default → bring it up, then apply user config
if ! $chrony_active; then
    if [ "$default_name" != "chrony" ]; then
        echo -e "${GREEN}SUCCESS${RESET}"
        exit 0
    fi

    pkg_var="TS_daemon_${chrony_idx}_package"
    svc_var="TS_daemon_${chrony_idx}_service"
    pkg="${!pkg_var}"
    svc="${!svc_var}"

    if ! is_package_installed "$pkg"; then
        apt-get install -y -q "$pkg" </dev/null >/dev/null 2>&1 || true
        if ! live_package_installed "$pkg"; then
            echo -e "${RED}FAILED${RESET}"
            exit 1
        fi
    fi

    systemctl unmask       "$svc" 2>/dev/null || true
    systemctl --now enable "$svc" 2>/dev/null || true

    if ! systemctl is-active "$svc" >/dev/null 2>&1; then
        echo -e "${RED}FAILED${RESET}"
        exit 1
    fi
fi

# ── Chrony is active — ensure config has the right user ──
run_as_var="TS_daemon_${chrony_idx}_run_as_user"
config_file_var="TS_daemon_${chrony_idx}_config_file"
run_as="${!run_as_var}"
config_file="${!config_file_var}"
[ -z "$run_as" ] && run_as="_chrony"

if [ -n "$config_file" ] && [ -f "$config_file" ]; then
    if ! grep -Pq "^\s*user\s+${run_as}\b" "$config_file" 2>/dev/null; then
        if grep -Pq '^\s*user\s+' "$config_file" 2>/dev/null; then
            sed -i "s/^\s*user\s\+.*/user ${run_as}/" "$config_file" 2>/dev/null || true
        else
            echo "user ${run_as}" >> "$config_file" 2>/dev/null || true
        fi
        systemctl reload-or-restart chrony.service >/dev/null 2>&1 || true
    fi
fi

# Match ONLY the real daemon (comm == "chronyd"), not wrapper scripts
wrong_user=$(ps -eo user,comm 2>/dev/null | awk -v u="$run_as" '$2=="chronyd" && $1!=u {print $1}')

if [[ -z "$wrong_user" ]]; then
    echo -e "${GREEN}SUCCESS${RESET}"
    exit 0
fi

echo -e "${RED}FAILED${RESET}"
exit 1
