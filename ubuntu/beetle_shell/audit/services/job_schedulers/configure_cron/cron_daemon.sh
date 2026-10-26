#!/usr/bin/env bash

NAME="ensure cron daemon is enabled and active"

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

[ -f "$DPKG_RAM_STORE" ] && source "$DPKG_RAM_STORE"
[ -f "$SERVICES_RAM_STORE" ] && source "$SERVICES_RAM_STORE"

daemon_count="${JS_daemon_count:-0}"

for ((i=0; i<daemon_count; i++)); do
    name_var="JS_daemon_${i}_name"
    package_var="JS_daemon_${i}_package"
    service_var="JS_daemon_${i}_service"
    required_var="JS_daemon_${i}_required"
    check_var="JS_daemon_${i}_check_if_installed"

    name="${!name_var}"
    package="${!package_var}"
    service="${!service_var}"
    required="${!required_var}"
    check_if_installed="${!check_var}"

    [ -z "$service" ] && continue
    [ -z "$package" ] && continue

    if [[ "$required" == "true" ]]; then
        # mandatory: must be installed + enabled + active
        if ! is_package_installed "$package"; then
            echo -e "${RED}NOT HARDENED${RESET}"
            exit 0
        fi
        enabled=$(systemctl is-enabled "$service" 2>/dev/null)
        active=$(systemctl is-active  "$service" 2>/dev/null)
        if [[ "$enabled" != "enabled" ]] || [[ "$active" != "active" ]]; then
            echo -e "${RED}NOT HARDENED${RESET}"
            exit 0
        fi
    elif [[ "$check_if_installed" == "true" ]]; then
        # optional: only check if installed
        if is_package_installed "$package"; then
            enabled=$(systemctl is-enabled "$service" 2>/dev/null)
            active=$(systemctl is-active  "$service" 2>/dev/null)
            if [[ "$enabled" != "enabled" ]] || [[ "$active" != "active" ]]; then
                echo -e "${RED}NOT HARDENED${RESET}"
                exit 0
            fi
        fi
    fi
done

echo -e "${GREEN}HARDENED${RESET}"
exit 0
