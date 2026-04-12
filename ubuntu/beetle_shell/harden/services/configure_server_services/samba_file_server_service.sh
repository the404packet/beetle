#!/usr/bin/env bash

NAME="ensure samba is not installed or smbd service is disabled"
SEVERITY="basic"

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

output=""

# Check if samba package is installed
if dpkg-query -s samba &>/dev/null; then

    # Package exists — check smbd service state
    enabled=$(systemctl is-enabled smbd.service 2>/dev/null | grep enabled)
    active=$(systemctl is-active smbd.service 2>/dev/null | grep '^active')

    if [[ -n "$enabled" ]] || [[ -n "$active" ]]; then
        output="samba is installed and smbd.service is enabled/active"
    fi
fi

if [[ -z "$output" ]]; then
    echo -e "${GREEN}HARDENED${RESET}"
else
    echo -e "${RED}NOT HARDENED${RESET}"
    echo "$output"
fi

exit 0
