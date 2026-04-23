#!/usr/bin/env bash

NAME='ensure libpam-pwquality is installed'
SEVERITY='basic'

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

if is_package_installed "libpam-pwquality"; then
    echo -e "${GREEN}SUCCESS${RESET}"
    exit 0
fi

if apt-get install -y libpam-pwquality 2>/dev/null; then
    echo -e "${GREEN}SUCCESS${RESET}"
else
    echo -e "${RED}FAILED${RESET}"
    exit 1
fi

exit 0
