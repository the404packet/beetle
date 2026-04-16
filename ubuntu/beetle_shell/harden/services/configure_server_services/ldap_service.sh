#!/usr/bin/env bash

NAME="ensure slapd is not installed or service is disabled"
SEVERITY="basic"

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

output=""

# Check if package is installed
if dpkg-query -s slapd &>/dev/null; then

    # Package exists — check service state
    enabled=$(systemctl is-enabled slapd.service 2>/dev/null | grep enabled)
    active=$(systemctl is-active slapd.service 2>/dev/null | grep '^active')

    if [[ -n "$enabled" ]] || [[ -n "$active" ]]; then
        output="slapd is installed and slapd.service is enabled/active"
    fi
fi

if [[ -z "$output" ]]; then
    echo -e "${GREEN}HARDENED${RESET}"
else
    echo -e "${RED}NOT HARDENED${RESET}"
    echo "$output"
fi

exit 0
