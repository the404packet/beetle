#!/usr/bin/env bash

NAME="ensure autofs is not installed or service is disabled"
SEVERITY="basic"

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

output=""

# Check if autofs package is installed
if dpkg-query -s autofs &>/dev/null; then

    # Package exists — check service state
    enabled=$(systemctl is-enabled autofs.service 2>/dev/null)
    active=$(systemctl is-active autofs.service 2>/dev/null)

    if [[ "$enabled" == "enabled" ]] || [[ "$active" == "active" ]]; then
        output="autofs is installed and service is enabled or active"
    fi
fi

if [[ -z "$output" ]]; then
    echo -e "${GREEN}HARDENED${RESET}"
else
    echo -e "${RED}NOT HARDENED${RESET}"
    echo "$output"
fi

exit 0
