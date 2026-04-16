#!/usr/bin/env bash

NAME="ensure X Window System is not installed"
SEVERITY="basic"

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

output=""

# Check if xserver-common package is installed
if dpkg-query -s xserver-common &>/dev/null; then
    output="xserver-common is installed (X Window System present)"
fi

if [[ -z "$output" ]]; then
    echo -e "${GREEN}HARDENED${RESET}"
else
    echo -e "${RED}NOT HARDENED${RESET}"
    echo "$output"
fi

exit 0
