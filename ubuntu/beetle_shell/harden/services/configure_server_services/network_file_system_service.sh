#!/usr/bin/env bash

NAME="ensure nfs-kernel-server is not installed or service is disabled"
SEVERITY="basic"

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

output=""

if dpkg-query -s nfs-kernel-server &>/dev/null; then

    # Package exists — check nfs server service state
    enabled=$(systemctl is-enabled nfs-server.service 2>/dev/null | grep enabled)
    active=$(systemctl is-active nfs-server.service 2>/dev/null | grep '^active')

    if [[ -n "$enabled" ]] || [[ -n "$active" ]]; then
        output="nfs-kernel-server is installed and nfs-server.service is enabled/active"
    fi
fi

if [[ -z "$output" ]]; then
    echo -e "${GREEN}HARDENED${RESET}"
else
    echo -e "${RED}NOT HARDENED${RESET}"
    echo "$output"
fi

exit 0
