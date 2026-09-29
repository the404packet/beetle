#!/usr/bin/env bash

NAME="ensure cron daemon is enabled and active"

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

[ -f "$DPKG_RAM_STORE" ] && source "$DPKG_RAM_STORE"
[ -f "$SERVICES_RAM_STORE" ] && source "$SERVICES_RAM_STORE"

export DEBIAN_FRONTEND=noninteractive

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
        # mandatory: install if missing, then enable + start
        if ! is_package_installed "$package"; then
            apt-get install -y -q "$package" </dev/null >/dev/null 2>&1 || true
            if ! live_package_installed "$package"; then
                echo -e "${RED}FAILED${RESET}"
                exit 1
            fi
        fi

        systemctl unmask        "$service" 2>/dev/null || true
        systemctl --now enable  "$service" 2>/dev/null || true

        enabled=$(systemctl is-enabled "$service" 2>/dev/null)
        active=$(systemctl is-active  "$service" 2>/dev/null)

        if [[ "$enabled" != "enabled" ]] || [[ "$active" != "active" ]]; then
            echo -e "${RED}FAILED${RESET}"
            exit 1
        fi
    elif [[ "$check_if_installed" == "true" ]]; then
        # optional: only enforce if installed; never install
        if is_package_installed "$package"; then
            systemctl unmask        "$service" 2>/dev/null || true
            systemctl --now enable  "$service" 2>/dev/null || true

            enabled=$(systemctl is-enabled "$service" 2>/dev/null)
            active=$(systemctl is-active  "$service" 2>/dev/null)

            if [[ "$enabled" != "enabled" ]] || [[ "$active" != "active" ]]; then
                echo -e "${RED}FAILED${RESET}"
                exit 1
            fi
        fi
    fi
done

echo -e "${GREEN}SUCCESS${RESET}"
exit 0
