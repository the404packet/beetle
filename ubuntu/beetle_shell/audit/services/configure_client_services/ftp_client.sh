#!/usr/bin/env bash

NAME="ensure ftp and tnftp are not installed"
SEVERITY="basic"

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

output=""

# Check if ftp or tnftp packages are installed
if dpkg-query -l | grep -E '^(ii)\s+(ftp|tnftp)\b' &>/dev/null; then
    output="ftp or tnftp is installed"
fi

if [[ -z "$output" ]]; then
    echo -e "${GREEN}HARDENED${RESET}"
else
    echo -e "${RED}NOT HARDENED${RESET}"
    echo "$output"
fi

exit 0