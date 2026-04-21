#!/usr/bin/env bash

NAME="ensure chrony is enabled and running"

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

[ -f "$DPKG_RAM_STORE" ] && source "$DPKG_RAM_STORE"
[ -f "$SERVICES_RAM_STORE" ] && source "$SERVICES_RAM_STORE"

is_enabled=$(systemctl is-enabled chrony.service 2>/dev/null)
is_active=$(systemctl is-active chrony.service 2>/dev/null)

# skip if timesyncd is in use instead
timesyncd_active=$(systemctl is-active systemd-timesyncd.service 2>/dev/null)
if [[ "$timesyncd_active" == "active" ]]; then
    systemctl stop chrony.service 2>/dev/null
    systemctl mask chrony.service 2>/dev/null
    apt-get purge -y chrony &>/dev/null
    apt-get autoremove -y chrony &>/dev/null
    echo -e "${GREEN}SUCCESS${RESET}"
    exit 0
fi

if [[ "$is_enabled" != "enabled" ]] && [[ "$is_active" != "active" ]]; then
    echo -e "${GREEN}SUCCESS${RESET}"
    exit 0
fi

systemctl unmask chrony.service 2>/dev/null
systemctl --now enable chrony.service 2>/dev/null

is_enabled=$(systemctl is-enabled chrony.service 2>/dev/null)
is_active=$(systemctl is-active chrony.service 2>/dev/null)

if [[ "$is_enabled" == "enabled" ]] && [[ "$is_active" == "active" ]]; then
    echo -e "${GREEN}SUCCESS${RESET}"
else
    echo -e "${RED}FAILED${RESET}"
    exit 1
fi

exit 0