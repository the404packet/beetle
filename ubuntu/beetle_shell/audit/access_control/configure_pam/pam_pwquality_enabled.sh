#!/usr/bin/env bash

NAME="ensure pam_pwquality module is enabled"
SEVERITY='basic'

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

if grep -P -- '\bpam_pwquality\.so\b' /etc/pam.d/common-password 2>/dev/null | grep -q .; then
    echo -e "${GREEN}HARDENED${RESET}"
else
    echo -e "${RED}NOT HARDENED${RESET}"
fi

exit 0
