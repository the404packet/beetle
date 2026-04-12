#!/usr/bin/env bash

NAME="ensure cups is not installed or service/socket is disabled"
SEVERITY="basic"

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

output=""

# Check if package is installed
if dpkg-query -s cups &>/dev/null; then

    # Package exists — check cups service and socket state
    enabled=$(systemctl is-enabled cups.service cups.socket 2>/dev/null | grep enabled)
    active=$(systemctl is-active cups.service cups.socket 2>/dev/null | grep '^active')

    if [[ -n "$enabled" ]] || [[ -n "$active" ]]; then
        output="cups is installed and cups.service or cups.socket is enabled/active"
    fi
fi

if [[ -z "$output" ]]; then
    echo -e "${GREEN}HARDENED${RESET}"
else
    echo -e "${RED}NOT HARDENED${RESET}"
    echo "$output"
fi

exit 0
