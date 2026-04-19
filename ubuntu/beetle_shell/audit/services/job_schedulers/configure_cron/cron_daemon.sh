#!/usr/bin/env bash

NAME="ensure cron daemon is enabled and active"

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

[ -f "$DPKG_RAM_STORE" ] && source "$DPKG_RAM_STORE"
[ -f "$SERVICES_RAM_STORE" ] && source "$SERVICES_RAM_STORE"

daemon_count="$JS_daemon_count"

for ((i=0; i<daemon_count; i++)); do
    name="JS_daemon_${i}_name"
    package="JS_daemon_${i}_package"
    service="JS_daemon_${i}_service"
    required="JS_daemon_${i}_required"

    name="${!name}"
    package="${!package}"
    service="${!service}"
    required="${!required}"

    if [[ "$required" == "true" ]]; then
        if ! is_package_installed "$package"; then
            echo -e "${RED}NOT HARDENED${RESET}"
            exit 0
        fi

        enabled=$(systemctl list-unit-files | awk -v svc="$service" '$1==svc{print $2}')
        active=$(systemctl list-units | awk -v svc="$service" '$1==svc{print $3}')

        if [[ "$enabled" != "enabled" ]] || [[ "$active" != "active" ]]; then
            echo -e "${RED}NOT HARDENED${RESET}"
            exit 0
        fi
    fi
done

echo -e "${GREEN}HARDENED${RESET}"
exit 0