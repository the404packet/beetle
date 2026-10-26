#!/usr/bin/env bash

NAME="ensure chrony is configured with authorized timeserver"

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

[ -f "$DPKG_RAM_STORE" ] && source "$DPKG_RAM_STORE"
[ -f "$SERVICES_RAM_STORE" ] && source "$SERVICES_RAM_STORE"

daemon_count="${TS_daemon_count:-0}"

# ── Find chrony index and check for other active daemon ──
chrony_idx=""
other_active=""
for ((i=0; i<daemon_count; i++)); do
    name_var="TS_daemon_${i}_name"
    svc_var="TS_daemon_${i}_service"
    name="${!name_var}"
    svc="${!svc_var}"
    [ -z "$svc" ] && continue

    if [ "$name" == "chrony" ]; then
        chrony_idx="$i"
        continue
    fi

    if systemctl is-active "$svc" >/dev/null 2>&1; then
        other_active="$name"
    fi
done

if [ -z "$chrony_idx" ]; then
    echo -e "${GREEN}HARDENED${RESET}"
    exit 0
fi

if [ -n "$other_active" ]; then
    echo -e "${GREEN}HARDENED${RESET}"
    exit 0
fi

# If chrony itself isn't running, not relevant
if ! systemctl is-active chrony.service >/dev/null 2>&1; then
    echo -e "${GREEN}HARDENED${RESET}"
    exit 0
fi

config_file_var="TS_daemon_${chrony_idx}_config_file"
config_dir_var="TS_daemon_${chrony_idx}_config_dir"
ntp_count_var="TS_daemon_${chrony_idx}_ntp_count"

config_file="${!config_file_var}"
config_dir="${!config_dir_var}"
ntp_count="${!ntp_count_var}"

config_files=("$config_file")
while IFS= read -r -d $'\0' f; do
    config_files+=("$f")
done < <(find "$config_dir" -type f -name "*.sources" -print0 2>/dev/null)

server_found=false
for f in "${config_files[@]}"; do
    [ -f "$f" ] || continue
    for ((n=0; n<ntp_count; n++)); do
        srv_var="TS_daemon_${chrony_idx}_ntp_${n}"
        srv="${!srv_var}"
        [ -z "$srv" ] && continue
        grep -Pq "^\s*(server|pool)\s+.*\b${srv}\b" "$f" 2>/dev/null && \
            server_found=true && break
    done
    $server_found && break
done

if $server_found; then
    echo -e "${GREEN}HARDENED${RESET}"
else
    echo -e "${RED}NOT HARDENED${RESET}"
fi

exit 0
