#!/usr/bin/env bash

NAME="ensure snmpd is not installed or service is disabled"
SEVERITY="basic"

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

output=""

# Check if snmpd package is installed
if dpkg-query -s snmpd &>/dev/null; then

    # Package exists — check snmpd service state
    enabled=$(systemctl is-enabled snmpd.service 2>/dev/null | grep enabled)
    active=$(systemctl is-active snmpd.service 2>/dev/null | grep '^active')

    if [[ -n "$enabled" ]] || [[ -n "$active" ]]; then
        output="snmpd is installed and snmpd.service is enabled/active"
    fi
fi

if [[ -z "$output" ]]; then
    echo -e "${GREEN}HARDENED${RESET}"
else
    echo -e "${RED}NOT HARDENED${RESET}"
    echo "$output"
fi

exit 0
