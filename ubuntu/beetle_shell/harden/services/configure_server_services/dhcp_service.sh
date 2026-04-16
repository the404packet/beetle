#!/usr/bin/env bash

NAME="ensure isc-dhcp-server is not installed or services are disabled"
SEVERITY="basic"

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

output=""

# Check if package is installed
if dpkg-query -s isc-dhcp-server &>/dev/null; then

    # Package exists — check IPv4 and IPv6 services
    enabled=$(systemctl is-enabled isc-dhcp-server.service isc-dhcp-server6.service 2>/dev/null | grep enabled)
    active=$(systemctl is-active isc-dhcp-server.service isc-dhcp-server6.service 2>/dev/null | grep '^active')

    if [[ -n "$enabled" ]] || [[ -n "$active" ]]; then
        output="isc-dhcp-server is installed and one or more services are enabled/active"
    fi
fi

if [[ -z "$output" ]]; then
    echo -e "${GREEN}HARDENED${RESET}"
else
    echo -e "${RED}NOT HARDENED${RESET}"
    echo "$output"
fi

exit 0
