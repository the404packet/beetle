#!/usr/bin/env bash

NAME="ensure ldap-utils is not installed"
SEVERITY="basic"

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

output=""

# Check if ldap-utils package is installed
if dpkg-query -s ldap-utils &>/dev/null; then
    output="ldap-utils is installed"
fi

if [[ -z "$output" ]]; then
    echo -e "${GREEN}HARDENED${RESET}"
else
    echo -e "${RED}NOT HARDENED${RESET}"
    echo "$output"
fi

exit 0