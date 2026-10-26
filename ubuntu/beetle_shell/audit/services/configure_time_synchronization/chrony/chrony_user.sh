#!/usr/bin/env bash

NAME="ensure chrony is running as user _chrony"

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

[ -f "$DPKG_RAM_STORE" ] && source "$DPKG_RAM_STORE"
[ -f "$SERVICES_RAM_STORE" ] && source "$SERVICES_RAM_STORE"

daemon_count="${TS_daemon_count:-0}"

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

if ! systemctl is-active chrony.service >/dev/null 2>&1; then
    echo -e "${GREEN}HARDENED${RESET}"
    exit 0
fi

run_as_var="TS_daemon_${chrony_idx}_run_as_user"
run_as="${!run_as_var}"
[ -z "$run_as" ] && run_as="_chrony"

# Match ONLY the real daemon (comm == "chronyd"), not wrapper scripts
wrong_user=$(ps -eo user,comm 2>/dev/null | awk -v u="$run_as" '$2=="chronyd" && $1!=u {print $1}')

if [[ -z "$wrong_user" ]]; then
    echo -e "${GREEN}HARDENED${RESET}"
else
    echo -e "${RED}NOT HARDENED${RESET}"
fi

exit 0
