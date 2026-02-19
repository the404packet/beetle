#!/usr/bin/env bash

NAME="ensure xinetd is not installed or service is disabled"
SEVERITY="basic"

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

output=""

# Check if xinetd package is installed
if dpkg-query -s xinetd &>/dev/null; then

    # Package exists — check xinetd service state
    enabled=$(systemctl is-enabled xinetd.service 2>/dev/null | grep enabled)
    active=$(systemctl is-active xinetd.service 2>/dev/null | grep '^active')

    if [[ -n "$enabled" ]] || [[ -n "$active" ]]; then
        output="xinetd is installed and xinetd.service is enabled/active"
    fi
fi

if [[ -z "$output" ]]; then
    echo -e "${GREEN}HARDENED${RESET}"
else
    echo -e "${RED}NOT HARDENED${RESET}"
    echo "$output"
fi

exit 0
