#!/usr/bin/env bash

NAME="ensure pam_unix module is enabled"
SEVERITY='basic'

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

if pam-auth-update --enable unix 2>/dev/null; then
    echo -e "${GREEN}SUCCESS${RESET}"
else
    echo -e "${RED}FAILED${RESET}"
    exit 1
fi

exit 0
