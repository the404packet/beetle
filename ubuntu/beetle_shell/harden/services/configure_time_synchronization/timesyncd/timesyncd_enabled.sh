#!/usr/bin/env bash

NAME="ensure systemd-timesyncd is enabled and running"

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

[ -f "$DPKG_RAM_STORE" ] && source "$DPKG_RAM_STORE"
[ -f "$SERVICES_RAM_STORE" ] && source "$SERVICES_RAM_STORE"

is_enabled=$(systemctl is-enabled systemd-timesyncd.service 2>/dev/null)
is_active=$(systemctl is-active systemd-timesyncd.service 2>/dev/null)

# skip if another time sync daemon is in use
chrony_active=$(systemctl is-active chrony.service 2>/dev/null)
if [[ "$chrony_active" == "active" ]]; then
    systemctl stop systemd-timesyncd.service 2>/dev/null
    systemctl mask systemd-timesyncd.service 2>/dev/null
    echo -e "${GREEN}SUCCESS${RESET}"
    exit 0
fi

if [[ "$is_enabled" != "enabled" ]] && [[ "$is_active" != "active" ]]; then
    echo -e "${GREEN}SUCCESS${RESET}"
    exit 0
fi

systemctl unmask systemd-timesyncd.service 2>/dev/null
systemctl --now enable systemd-timesyncd.service 2>/dev/null

is_enabled=$(systemctl is-enabled systemd-timesyncd.service 2>/dev/null)
is_active=$(systemctl is-active systemd-timesyncd.service 2>/dev/null)

if [[ "$is_enabled" == "enabled" ]] && [[ "$is_active" == "active" ]]; then
    echo -e "${GREEN}SUCCESS${RESET}"
else
    echo -e "${RED}FAILED${RESET}"
    exit 1
fi

exit 0