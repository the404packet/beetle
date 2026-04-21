#!/usr/bin/env bash

NAME="ensure chrony is configured with authorized timeserver"

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

[ -f "$DPKG_RAM_STORE" ] && source "$DPKG_RAM_STORE"
[ -f "$SERVICES_RAM_STORE" ] && source "$SERVICES_RAM_STORE"

is_enabled=$(systemctl is-enabled chrony.service 2>/dev/null)
is_active=$(systemctl is-active chrony.service 2>/dev/null)

if [[ "$is_enabled" != "enabled" ]] && [[ "$is_active" != "active" ]]; then
    echo -e "${GREEN}HARDENED${RESET}"
    exit 0
fi

daemon_count="$TS_daemon_count"
chrony_idx=""
for ((i=0; i<daemon_count; i++)); do
    name_var="TS_daemon_${i}_name"
    if [[ "${!name_var}" == "chrony" ]]; then
        chrony_idx="$i"
        break
    fi
done

if [[ -z "$chrony_idx" ]]; then
    echo -e "${RED}NOT HARDENED${RESET}"
    exit 0
fi

config_file_var="TS_daemon_${chrony_idx}_config_file"
config_dir_var="TS_daemon_${chrony_idx}_config_dir"
ntp_count_var="TS_daemon_${chrony_idx}_ntp_count"

config_file="${!config_file_var}"
config_dir="${!config_dir_var}"
ntp_count="${!ntp_count_var}"

# collect all config files
config_files=("$config_file")
while IFS= read -r -d $'\0' f; do
    config_files+=("$f")
done < <(find "$config_dir" -type f -name "*.sources" -print0 2>/dev/null)

server_found=false
for f in "${config_files[@]}"; do
    [ -f "$f" ] || continue
    if grep -Pq '^\s*(server|pool)\s+\S+' "$f" 2>/dev/null; then
        for ((n=0; n<ntp_count; n++)); do
            srv_var="TS_daemon_${chrony_idx}_ntp_${n}"
            srv="${!srv_var}"
            grep -Pq "^\s*(server|pool)\s+.*\b${srv}\b" "$f" 2>/dev/null && \
                server_found=true && break
        done
    fi
done

if $server_found; then
    echo -e "${GREEN}HARDENED${RESET}"
else
    echo -e "${RED}NOT HARDENED${RESET}"
fi

exit 0