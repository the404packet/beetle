#!/usr/bin/env bash

NAME="ensure cron daemon is enabled and active"

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

[ -f "$DPKG_RAM_STORE" ] && source "$DPKG_RAM_STORE"
[ -f "$SERVICES_RAM_STORE" ] && source "$SERVICES_RAM_STORE"

daemon_count="$JS_daemon_count"

for ((i=0; i<daemon_count; i++)); do
    name_var="JS_daemon_${i}_name"
    package_var="JS_daemon_${i}_package"
    service_var="JS_daemon_${i}_service"
    required_var="JS_daemon_${i}_required"

    name="${!name_var}"
    package="${!package_var}"
    service="${!service_var}"
    required="${!required_var}"

    if [[ "$required" == "true" ]]; then
        if ! is_package_installed "$package"; then
            apt-get install -y "$package" </dev/null &>/dev/null
            if ! live_package_installed "$package"; then
                echo -e "${RED}FAILED${RESET}"
                exit 1
            fi
        fi

        systemctl unmask "$service" 2>/dev/null
        systemctl --now enable "$service" 2>/dev/null

        # Direct systemctl predicates — no output-format parsing
        enabled=$(systemctl is-enabled "$service" 2>/dev/null)
        active=$(systemctl is-active  "$service" 2>/dev/null)

        if [[ "$enabled" != "enabled" ]] || [[ "$active" != "active" ]]; then
            echo -e "${RED}FAILED${RESET}"
            exit 1
        fi
    fi
done

echo -e "${GREEN}SUCCESS${RESET}"
exit 0