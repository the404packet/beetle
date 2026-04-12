#!/usr/bin/env bash

NAME="ensure tftpd-hpa is not installed or service is disabled"
SEVERITY="basic"

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

output=""

# Check if tftpd-hpa package is installed
if dpkg-query -s tftpd-hpa &>/dev/null; then

    # Package exists — check tftpd-hpa service state
    enabled=$(systemctl is-enabled tftpd-hpa.service 2>/dev/null | grep enabled)
    active=$(systemctl is-active tftpd-hpa.service 2>/dev/null | grep '^active')

    if [[ -n "$enabled" ]] || [[ -n "$active" ]]; then
        output="tftpd-hpa is installed and tftpd-hpa.service is enabled/active"
    fi
fi

if [[ -z "$output" ]]; then
    echo -e "${GREEN}HARDENED${RESET}"
else
    echo -e "${RED}NOT HARDENED${RESET}"
    echo "$output"
fi

exit 0
