#!/usr/bin/env bash

NAME="ensure bind9 is not installed or named service is disabled"
SEVERITY="basic"

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

output=""

# Check if package is installed
if dpkg-query -s bind9 &>/dev/null; then

    # Package exists — check named service state
    enabled=$(systemctl is-enabled named.service 2>/dev/null | grep enabled)
    active=$(systemctl is-active named.service 2>/dev/null | grep '^active')

    if [[ -n "$enabled" ]] || [[ -n "$active" ]]; then
        output="bind9 is installed and named.service is enabled/active"
    fi
fi

if [[ -z "$output" ]]; then
    echo -e "${GREEN}HARDENED${RESET}"
else
    echo -e "${RED}NOT HARDENED${RESET}"
    echo "$output"
fi

exit 0
