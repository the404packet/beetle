#!/usr/bin/env bash

NAME="ensure vsftpd is not installed or service is disabled"
SEVERITY="basic"

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

output=""

# Check if package is installed
if dpkg-query -s vsftpd &>/dev/null; then

    # Package exists — check service state
    enabled=$(systemctl is-enabled vsftpd.service 2>/dev/null | grep enabled)
    active=$(systemctl is-active vsftpd.service 2>/dev/null | grep '^active')

    if [[ -n "$enabled" ]] || [[ -n "$active" ]]; then
        output="vsftpd is installed and vsftpd.service is enabled/active"
    fi
fi

if [[ -z "$output" ]]; then
    echo -e "${GREEN}HARDENED${RESET}"
else
    echo -e "${RED}NOT HARDENED${RESET}"
    echo "$output"
fi

exit 0
