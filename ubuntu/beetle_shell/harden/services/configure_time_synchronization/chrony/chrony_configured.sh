#!/usr/bin/env bash

NAME="ensure chrony is configured with authorized timeserver"

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

[ -f "$DPKG_RAM_STORE" ] && source "$DPKG_RAM_STORE"
[ -f "$SERVICES_RAM_STORE" ] && source "$SERVICES_RAM_STORE"

export DEBIAN_FRONTEND=noninteractive

daemon_count="${TS_daemon_count:-0}"
default_name="${TS_default:-}"

# ── Determine state of every daemon ──
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

# No chrony in JSON → nothing to do
if [ -z "$chrony_idx" ]; then
    echo -e "${GREEN}SUCCESS${RESET}"
    exit 0
fi

# Another daemon is active → chrony not relevant
if [ -n "$other_active" ]; then
    echo -e "${GREEN}SUCCESS${RESET}"
    exit 0
fi

# Chrony not active:
#   - If chrony is NOT the default → no-op
#   - If chrony IS the default → bring it up, then configure
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

# ── Chrony is now active — configure it ──
config_dir_var="TS_daemon_${chrony_idx}_config_dir"
ntp_count_var="TS_daemon_${chrony_idx}_ntp_count"
config_dir="${!config_dir_var}"
ntp_count="${!ntp_count_var}"

config_dir="${config_dir%/}/"
[ -d "$config_dir" ] || mkdir -p "$config_dir" 2>/dev/null || true

drop_in="${config_dir}60-sources.sources"

{
    echo "# The maxsources option is unique to the pool directive"
    for ((n=0; n<ntp_count; n++)); do
        srv_var="TS_daemon_${chrony_idx}_ntp_${n}"
        srv="${!srv_var}"
        [ -n "$srv" ] && echo "pool ${srv} iburst maxsources 4"
    done
} > "$drop_in" 2>/dev/null || true

chronyc reload sources                       >/dev/null 2>&1 || true
systemctl reload-or-restart chrony.service   >/dev/null 2>&1 || true

server_found=false
for ((n=0; n<ntp_count; n++)); do
    srv_var="TS_daemon_${chrony_idx}_ntp_${n}"
    srv="${!srv_var}"
    [ -z "$srv" ] && continue
    grep -Pq "^\s*(server|pool)\s+.*\b${srv}\b" "$drop_in" 2>/dev/null && \
        server_found=true && break
done

if $server_found; then
    echo -e "${GREEN}SUCCESS${RESET}"
    exit 0
fi

echo -e "${RED}FAILED${RESET}"
exit 1
