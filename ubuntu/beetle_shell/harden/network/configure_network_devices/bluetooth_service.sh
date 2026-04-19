#!/usr/bin/env bash

NAME="ensure bluetooth services are not in use"

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

[ -f "$DPKG_RAM_STORE" ] && source "$DPKG_RAM_STORE"
[ -f "$NETWORK_RAM_STORE" ] && source "$NETWORK_RAM_STORE"

pkg="$NS_bluetooth_package"
svc="$NS_bluetooth_service"
restrict="$NS_bluetooth_restrict"

if [[ "$restrict" != "true" ]]; then
    echo -e "${GREEN}SUCCESS${RESET}"
    exit 0
fi

if ! is_package_installed "$pkg"; then
    echo -e "${GREEN}SUCCESS${RESET}"
    exit 0
fi

systemctl stop "$svc" 2>/dev/null
apt-get purge -y "$pkg" &>/dev/null
unset_package "$pkg"

if is_package_installed "$pkg"; then
    # has dependency — mask instead
    systemctl mask "$svc" 2>/dev/null
    enabled=$(systemctl is-enabled "$svc" 2>/dev/null)
    active=$(systemctl is-active "$svc" 2>/dev/null)
    if [[ "$enabled" == "enabled" ]] || [[ "$active" == "active" ]]; then
        echo -e "${RED}FAILED${RESET}"
        exit 1
    fi
fi

echo -e "${GREEN}SUCCESS${RESET}"
exit 0