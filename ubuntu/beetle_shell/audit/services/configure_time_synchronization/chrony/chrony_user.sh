#!/usr/bin/env bash

NAME="ensure chrony is running as user _chrony"

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

run_as_var="TS_daemon_${chrony_idx}_run_as_user"
run_as="${!run_as_var}"

wrong_user=$(ps -ef | awk '/[c]hronyd/ && $1!="'"$run_as"'" {print $1}')

if [[ -z "$wrong_user" ]]; then
    echo -e "${GREEN}HARDENED${RESET}"
else
    echo -e "${RED}NOT HARDENED${RESET}"
fi

exit 0