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

run_as_var="TS_daemon_${chrony_idx}_run_as_user"
config_file_var="TS_daemon_${chrony_idx}_config_file"
run_as="${!run_as_var}"
config_file="${!config_file_var}"

# set user in config if not set
if ! grep -Pq "^\s*user\s+${run_as}" "$config_file" 2>/dev/null; then
    if grep -Pq '^\s*user\s+' "$config_file" 2>/dev/null; then
        sed -i "s/^\s*user\s+.*/user ${run_as}/" "$config_file"
    else
        echo "user ${run_as}" >> "$config_file"
    fi
    systemctl reload-or-restart chrony.service 2>/dev/null
fi

wrong_user=$(ps -ef | awk '/[c]hronyd/ && $1!="'"$run_as"'" {print $1}')

if [[ -z "$wrong_user" ]]; then
    echo -e "${GREEN}SUCCESS${RESET}"
else
    echo -e "${RED}FAILED${RESET}"
    exit 1
fi

exit 0