#!/usr/bin/env bash

NAME="ensure avahi-daemon is not installed or service/socket is disabled"
SEVERITY="basic"

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

output=""

# Check if package is installed
if dpkg-query -s avahi-daemon &>/dev/null; then

    # Package exists — check service and socket states
    enabled=$(systemctl is-enabled avahi-daemon.service avahi-daemon.socket 2>/dev/null | grep enabled)
    active=$(systemctl is-active avahi-daemon.service avahi-daemon.socket 2>/dev/null | grep '^active')

    if [[ -n "$enabled" ]] || [[ -n "$active" ]]; then
        output="avahi-daemon is installed and service or socket is enabled/active"
    fi
fi

if [[ -z "$output" ]]; then
    echo -e "${GREEN}HARDENED${RESET}"
else
    echo -e "${RED}NOT HARDENED${RESET}"
    echo "$output"
fi

exit 0
