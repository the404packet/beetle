#!/usr/bin/env bash

NAME="ensure sudo is installed"
SEVERITY='basic'

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

if is_package_installed "sudo" || is_package_installed "sudo-ldap"; then
    echo -e "${GREEN}HARDENED${RESET}"
else
    echo -e "${RED}NOT HARDENED${RESET}"
fi

exit 0