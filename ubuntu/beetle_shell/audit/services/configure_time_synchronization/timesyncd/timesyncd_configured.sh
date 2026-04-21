#!/usr/bin/env bash

NAME="ensure systemd-timesyncd configured with authorized timeserver"

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

[ -f "$DPKG_RAM_STORE" ] && source "$DPKG_RAM_STORE"
[ -f "$SERVICES_RAM_STORE" ] && source "$SERVICES_RAM_STORE"

# skip if timesyncd not in use
is_enabled=$(systemctl is-enabled systemd-timesyncd.service 2>/dev/null)
is_active=$(systemctl is-active systemd-timesyncd.service 2>/dev/null)

if [[ "$is_enabled" != "enabled" ]] && [[ "$is_active" != "active" ]]; then
    echo -e "${GREEN}HARDENED${RESET}"
    exit 0
fi

# get timesyncd daemon index
ts_idx=""
daemon_count="$TS_daemon_count"
for ((i=0; i<daemon_count; i++)); do
    name_var="TS_daemon_${i}_name"
    if [[ "${!name_var}" == "systemd-timesyncd" ]]; then
        ts_idx="$i"
        break
    fi
done

if [[ -z "$ts_idx" ]]; then
    echo -e "${RED}NOT HARDENED${RESET}"
    exit 0
fi

config_file_var="TS_daemon_${ts_idx}_config_file"
config_dir_var="TS_daemon_${ts_idx}_config_dir"
ntp_count_var="TS_daemon_${ts_idx}_ntp_count"
fallback_count_var="TS_daemon_${ts_idx}_fallback_count"

config_file="${!config_file_var}"
config_dir="${!config_dir_var}"
ntp_count="${!ntp_count_var}"
fallback_count="${!fallback_count_var}"

# collect all config files
config_files=("$config_file")
while IFS= read -r -d $'\0' f; do
    config_files+=("$f")
done < <(find "$config_dir" -type f -name "*.conf" -print0 2>/dev/null)

# check NTP servers
ntp_found=false
fallback_found=false

for f in "${config_files[@]}"; do
    [ -f "$f" ] || continue
    if grep -Pq '^\s*NTP=\S+' "$f" 2>/dev/null; then
        for ((n=0; n<ntp_count; n++)); do
            srv_var="TS_daemon_${ts_idx}_ntp_${n}"
            srv="${!srv_var}"
            grep -Pq "^\s*NTP=.*\b${srv}\b" "$f" 2>/dev/null && ntp_found=true
        done
    fi
    if grep -Pq '^\s*FallbackNTP=\S+' "$f" 2>/dev/null; then
        for ((n=0; n<fallback_count; n++)); do
            srv_var="TS_daemon_${ts_idx}_fallback_${n}"
            srv="${!srv_var}"
            grep -Pq "^\s*FallbackNTP=.*\b${srv}\b" "$f" 2>/dev/null && fallback_found=true
        done
    fi
done

if $ntp_found || $fallback_found; then
    echo -e "${GREEN}HARDENED${RESET}"
else
    echo -e "${RED}NOT HARDENED${RESET}"
fi

exit 0