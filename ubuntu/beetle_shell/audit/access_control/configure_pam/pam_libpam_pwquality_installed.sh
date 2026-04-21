#!/usr/bin/env bash

NAME='ensure libpam-pwquality is installed'
SEVERITY='basic'

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

if is_package_installed "libpam-pwquality"; then
    echo -e "${GREEN}HARDENED${RESET}"
else
    echo -e "${RED}NOT HARDENED${RESET}"
fi

exit 0
