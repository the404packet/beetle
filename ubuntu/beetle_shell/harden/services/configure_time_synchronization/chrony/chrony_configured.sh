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
    echo -e "${GREEN}SUCCESS${RESET}"
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
    echo -e "${RED}FAILED${RESET}"
    exit 1
fi

config_dir_var="TS_daemon_${chrony_idx}_config_dir"
ntp_count_var="TS_daemon_${chrony_idx}_ntp_count"
config_dir="${!config_dir_var}"
ntp_count="${!ntp_count_var}"

[ ! -d "$config_dir" ] && mkdir -p "$config_dir"

drop_in="${config_dir}60-sources.sources"

# build server lines
{
    echo ""
    echo "# The maxsources option is unique to the pool directive"
    for ((n=0; n<ntp_count; n++)); do
        srv_var="TS_daemon_${chrony_idx}_ntp_${n}"
        echo "pool ${!srv_var} iburst maxsources 4"
    done
} >> "$drop_in"

chronyc reload sources &>/dev/null
systemctl reload-or-restart chrony.service 2>/dev/null

# verify
server_found=false
for ((n=0; n<ntp_count; n++)); do
    srv_var="TS_daemon_${chrony_idx}_ntp_${n}"
    srv="${!srv_var}"
    grep -Pq "^\s*(server|pool)\s+.*\b${srv}\b" "$drop_in" 2>/dev/null && \
        server_found=true && break
done

if $server_found; then
    echo -e "${GREEN}SUCCESS${RESET}"
else
    echo -e "${RED}FAILED${RESET}"
    exit 1
fi

exit 0