#!/usr/bin/env bash

NAME="ensure systemd-timesyncd configured with authorized timeserver"

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

[ -f "$DPKG_RAM_STORE" ] && source "$DPKG_RAM_STORE"
[ -f "$SERVICES_RAM_STORE" ] && source "$SERVICES_RAM_STORE"

daemon_count="${TS_daemon_count:-0}"

# ── Find our index and the active daemon in one pass ──
ts_idx=""
other_active=""
for ((i=0; i<daemon_count; i++)); do
    name_var="TS_daemon_${i}_name"
    svc_var="TS_daemon_${i}_service"
    name="${!name_var}"
    svc="${!svc_var}"
    [ -z "$svc" ] && continue

    if [ "$name" == "systemd-timesyncd" ]; then
        ts_idx="$i"
        continue
    fi

    if systemctl is-active "$svc" >/dev/null 2>&1; then
        other_active="$name"
    fi
done

# If timesyncd is not in JSON, nothing to harden
if [ -z "$ts_idx" ]; then
    echo -e "${GREEN}SUCCESS${RESET}"
    exit 0
fi

# If some other daemon is the active one, timesyncd is not relevant
if [ -n "$other_active" ]; then
    echo -e "${GREEN}SUCCESS${RESET}"
    exit 0
fi

# If timesyncd itself isn't running, not relevant
if ! systemctl is-active systemd-timesyncd.service >/dev/null 2>&1; then
    echo -e "${GREEN}SUCCESS${RESET}"
    exit 0
fi

config_dir_var="TS_daemon_${ts_idx}_config_dir"
ntp_count_var="TS_daemon_${ts_idx}_ntp_count"
fallback_count_var="TS_daemon_${ts_idx}_fallback_count"

config_dir="${!config_dir_var}"
ntp_count="${!ntp_count_var}"
fallback_count="${!fallback_count_var}"

# Normalize trailing slash
config_dir="${config_dir%/}/"

[ -d "$config_dir" ] || mkdir -p "$config_dir" 2>/dev/null || true

drop_in="${config_dir}60-timesyncd.conf"

# build NTP line
ntp_line="NTP="
for ((n=0; n<ntp_count; n++)); do
    srv_var="TS_daemon_${ts_idx}_ntp_${n}"
    srv="${!srv_var}"
    [ -n "$srv" ] && ntp_line+="${srv} "
done
ntp_line="${ntp_line% }"

# build FallbackNTP line
fallback_line="FallbackNTP="
for ((n=0; n<fallback_count; n++)); do
    srv_var="TS_daemon_${ts_idx}_fallback_${n}"
    srv="${!srv_var}"
    [ -n "$srv" ] && fallback_line+="${srv} "
done
fallback_line="${fallback_line% }"

# write drop-in idempotently (overwrite, not append)
{
    printf '%s\n' "[Time]"
    printf '%s\n' "$ntp_line"
    printf '%s\n' "$fallback_line"
} > "$drop_in" 2>/dev/null || true

systemctl reload-or-restart systemd-timesyncd.service 2>/dev/null || true

# verify
ntp_found=false
fallback_found=false
for ((n=0; n<ntp_count; n++)); do
    srv_var="TS_daemon_${ts_idx}_ntp_${n}"
    srv="${!srv_var}"
    [ -z "$srv" ] && continue
    grep -Pq "^\s*NTP=.*\b${srv}\b" "$drop_in" 2>/dev/null && ntp_found=true
done
for ((n=0; n<fallback_count; n++)); do
    srv_var="TS_daemon_${ts_idx}_fallback_${n}"
    srv="${!srv_var}"
    [ -z "$srv" ] && continue
    grep -Pq "^\s*FallbackNTP=.*\b${srv}\b" "$drop_in" 2>/dev/null && fallback_found=true
done

if $ntp_found && $fallback_found; then
    echo -e "${GREEN}SUCCESS${RESET}"
else
    echo -e "${RED}FAILED${RESET}"
    exit 1
fi

exit 0
