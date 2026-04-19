#!/usr/bin/env bash

NAME="ensure systemd-timesyncd configured with authorized timeserver"

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

[ -f "$DPKG_RAM_STORE" ] && source "$DPKG_RAM_STORE"
[ -f "$SERVICES_RAM_STORE" ] && source "$SERVICES_RAM_STORE"

is_enabled=$(systemctl is-enabled systemd-timesyncd.service 2>/dev/null)
is_active=$(systemctl is-active systemd-timesyncd.service 2>/dev/null)

if [[ "$is_enabled" != "enabled" ]] && [[ "$is_active" != "active" ]]; then
    echo -e "${GREEN}SUCCESS${RESET}"
    exit 0
fi

daemon_count="$TS_daemon_count"
ts_idx=""
for ((i=0; i<daemon_count; i++)); do
    name_var="TS_daemon_${i}_name"
    if [[ "${!name_var}" == "systemd-timesyncd" ]]; then
        ts_idx="$i"
        break
    fi
done

if [[ -z "$ts_idx" ]]; then
    echo -e "${RED}FAILED${RESET}"
    exit 1
fi

config_dir_var="TS_daemon_${ts_idx}_config_dir"
ntp_count_var="TS_daemon_${ts_idx}_ntp_count"
fallback_count_var="TS_daemon_${ts_idx}_fallback_count"

config_dir="${!config_dir_var}"
ntp_count="${!ntp_count_var}"
fallback_count="${!fallback_count_var}"

[ ! -d "$config_dir" ] && mkdir -p "$config_dir"

drop_in="${config_dir}60-timesyncd.conf"

# build NTP line
ntp_line="NTP="
for ((n=0; n<ntp_count; n++)); do
    srv_var="TS_daemon_${ts_idx}_ntp_${n}"
    ntp_line+="${!srv_var} "
done
ntp_line="${ntp_line% }"

# build FallbackNTP line
fallback_line="FallbackNTP="
for ((n=0; n<fallback_count; n++)); do
    srv_var="TS_daemon_${ts_idx}_fallback_${n}"
    fallback_line+="${!srv_var} "
done
fallback_line="${fallback_line% }"

# write drop-in
if grep -Psq '^\s*\[Time\]' "$drop_in" 2>/dev/null; then
    printf '%s\n' "" "$ntp_line" "$fallback_line" >> "$drop_in"
else
    printf '%s\n' "[Time]" "$ntp_line" "$fallback_line" > "$drop_in"
fi

systemctl reload-or-restart systemd-timesyncd.service 2>/dev/null

# verify
ntp_found=false
fallback_found=false
for ((n=0; n<ntp_count; n++)); do
    srv_var="TS_daemon_${ts_idx}_ntp_${n}"
    srv="${!srv_var}"
    grep -Pq "^\s*NTP=.*\b${srv}\b" "$drop_in" 2>/dev/null && ntp_found=true
done
for ((n=0; n<fallback_count; n++)); do
    srv_var="TS_daemon_${ts_idx}_fallback_${n}"
    srv="${!srv_var}"
    grep -Pq "^\s*FallbackNTP=.*\b${srv}\b" "$drop_in" 2>/dev/null && fallback_found=true
done

if $ntp_found || $fallback_found; then
    echo -e "${GREEN}SUCCESS${RESET}"
else
    echo -e "${RED}FAILED${RESET}"
    exit 1
fi

exit 0