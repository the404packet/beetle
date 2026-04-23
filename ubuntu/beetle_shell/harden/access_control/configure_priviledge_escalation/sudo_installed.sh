#!/usr/bin/env bash

NAME="ensure sudo is installed"
SEVERITY='basic'

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

if is_package_installed "sudo" || is_package_installed "sudo-ldap"; then
    echo -e "${GREEN}SUCCESS${RESET}"
    exit 0
fi

if apt-get install -y sudo >/dev/null 2>&1; then
    echo -e "${GREEN}SUCCESS${RESET}"
else
    echo -e "${RED}FAILED${RESET}"
    exit 1
fi

exit 0