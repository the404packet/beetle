#!/usr/bin/env bash

NAME='ensure pam_pwhistory module is enabled'
SEVERITY='basic'

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

if grep -P -- '\bpam_pwhistory\.so\b' /etc/pam.d/common-password 2>/dev/null | grep -q .; then
    echo -e "${GREEN}HARDENED${RESET}"
else
    echo -e "${RED}NOT HARDENED${RESET}"
fi

exit 0
