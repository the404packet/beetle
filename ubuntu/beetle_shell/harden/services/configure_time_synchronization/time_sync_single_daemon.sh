#!/usr/bin/env bash

NAME="ensure a single time synchronization daemon is in use"

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

[ -f "$DPKG_RAM_STORE" ] && source "$DPKG_RAM_STORE"
[ -f "$SERVICES_RAM_STORE" ] && source "$SERVICES_RAM_STORE"

daemon_count="$TS_daemon_count"
active_daemons=()

for ((i=0; i<daemon_count; i++)); do
    service_var="TS_daemon_${i}_service"
    package_var="TS_daemon_${i}_package"
    service="${!service_var}"
    package="${!package_var}"

    is_enabled=$(systemctl is-enabled "$service" 2>/dev/null)
    is_active=$(systemctl is-active "$service" 2>/dev/null)

    if [[ "$is_enabled" == "enabled" ]] || [[ "$is_active" == "active" ]]; then
        active_daemons+=("$i")
    fi
done

if [[ "${#active_daemons[@]}" -eq 1 ]]; then
    echo -e "${GREEN}SUCCESS${RESET}"
    exit 0
fi

# none active — enable first daemon (systemd-timesyncd)
if [[ "${#active_daemons[@]}" -eq 0 ]]; then
    service_var="TS_daemon_0_service"
    service="${!service_var}"
    systemctl unmask "$service" 2>/dev/null
    systemctl --now enable "$service" 2>/dev/null

    is_active=$(systemctl is-active "$service" 2>/dev/null)
    if [[ "$is_active" != "active" ]]; then
        echo -e "${RED}FAILED${RESET}"
        exit 1
    fi
    echo -e "${GREEN}SUCCESS${RESET}"
    exit 0
fi

# more than one active — keep first found, disable rest
keep="${active_daemons[0]}"
for idx in "${active_daemons[@]}"; do
    if [[ "$idx" != "$keep" ]]; then
        service_var="TS_daemon_${idx}_service"
        package_var="TS_daemon_${idx}_package"
        service="${!service_var}"
        package="${!package_var}"
        systemctl stop "$service" 2>/dev/null
        systemctl mask "$service" 2>/dev/null
        apt-get purge -y "$package" &>/dev/null
    fi
done

active_count=0
for ((i=0; i<daemon_count; i++)); do
    service_var="TS_daemon_${i}_service"
    service="${!service_var}"
    is_active=$(systemctl is-active "$service" 2>/dev/null)
    [[ "$is_active" == "active" ]] && ((active_count++))
done

if [[ "$active_count" -eq 1 ]]; then
    echo -e "${GREEN}SUCCESS${RESET}"
else
    echo -e "${RED}FAILED${RESET}"
    exit 1
fi

exit 0