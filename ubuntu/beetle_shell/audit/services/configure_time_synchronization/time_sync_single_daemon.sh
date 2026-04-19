#!/usr/bin/env bash

NAME="ensure a single time synchronization daemon is in use"

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

[ -f "$DPKG_RAM_STORE" ] && source "$DPKG_RAM_STORE"
[ -f "$SERVICES_RAM_STORE" ] && source "$SERVICES_RAM_STORE"

daemon_count="$TS_daemon_count"
active_count=0

for ((i=0; i<daemon_count; i++)); do
    service_var="TS_daemon_${i}_service"
    service="${!service_var}"

    is_enabled=$(systemctl is-enabled "$service" 2>/dev/null)
    is_active=$(systemctl is-active "$service" 2>/dev/null)

    if [[ "$is_enabled" == "enabled" ]] || [[ "$is_active" == "active" ]]; then
        ((active_count++))
    fi
done

if [[ "$active_count" -eq 1 ]]; then
    echo -e "${GREEN}HARDENED${RESET}"
else
    echo -e "${RED}NOT HARDENED${RESET}"
fi

exit 0