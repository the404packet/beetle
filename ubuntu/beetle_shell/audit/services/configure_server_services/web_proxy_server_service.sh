#!/usr/bin/env bash

NAME="ensure squid is not installed or service is disabled"
SEVERITY="basic"

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

output=""

# Check if squid package is installed
if dpkg-query -s squid &>/dev/null; then

    # Package exists — check squid service state
    enabled=$(systemctl is-enabled squid.service 2>/dev/null | grep enabled)
    active=$(systemctl is-active squid.service 2>/dev/null | grep '^active')

    if [[ -n "$enabled" ]] || [[ -n "$active" ]]; then
        output="squid is installed and squid.service is enabled/active"
    fi
fi

if [[ -z "$output" ]]; then
    echo -e "${GREEN}HARDENED${RESET}"
else
    echo -e "${RED}NOT HARDENED${RESET}"
    echo "$output"
fi

exit 0
