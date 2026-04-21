#!/usr/bin/env bash

NAME="ensure systemd-timesyncd is enabled and running"

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

[ -f "$DPKG_RAM_STORE" ] && source "$DPKG_RAM_STORE"
[ -f "$SERVICES_RAM_STORE" ] && source "$SERVICES_RAM_STORE"

# skip if timesyncd not in use
is_enabled=$(systemctl is-enabled systemd-timesyncd.service 2>/dev/null)
is_active=$(systemctl is-active systemd-timesyncd.service 2>/dev/null)

if [[ "$is_enabled" != "enabled" ]] && [[ "$is_active" != "active" ]]; then
    echo -e "${GREEN}HARDENED${RESET}"
    exit 0
fi

if [[ "$is_enabled" == "enabled" ]] && [[ "$is_active" == "active" ]]; then
    echo -e "${GREEN}HARDENED${RESET}"
else
    echo -e "${RED}NOT HARDENED${RESET}"
fi

exit 0