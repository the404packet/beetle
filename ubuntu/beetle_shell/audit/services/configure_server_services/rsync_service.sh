#!/usr/bin/env bash

NAME="ensure rsync is not installed or service is disabled"
SEVERITY="basic"

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

output=""

# Check if package is installed
if dpkg-query -s rsync &>/dev/null; then

    # Package exists — check rsync service state
    enabled=$(systemctl is-enabled rsync.service 2>/dev/null | grep enabled)
    active=$(systemctl is-active rsync.service 2>/dev/null | grep '^active')

    if [[ -n "$enabled" ]] || [[ -n "$active" ]]; then
        output="rsync is installed and rsync.service is enabled/active"
    fi
fi

if [[ -z "$output" ]]; then
    echo -e "${GREEN}HARDENED${RESET}"
else
    echo -e "${RED}NOT HARDENED${RESET}"
    echo "$output"
fi

exit 0
