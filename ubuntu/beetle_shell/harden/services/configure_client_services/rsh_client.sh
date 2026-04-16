#!/usr/bin/env bash

NAME="ensure rsh-client is not installed"
SEVERITY="basic"

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

output=""

# Check if rsh-client package is installed
if dpkg-query -s rsh-client &>/dev/null; then
    output="rsh-client is installed"
fi

if [[ -z "$output" ]]; then
    echo -e "${GREEN}HARDENED${RESET}"
else
    echo -e "${RED}NOT HARDENED${RESET}"
    echo "$output"
fi

exit 0