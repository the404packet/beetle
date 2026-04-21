#!/usr/bin/env bash

NAME='ensure pam_pwhistory includes use_authtok'
SEVERITY='basic'

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

if grep -Psi -- "^\h*password\h+[^#\n\r]+\h+pam_pwhistory\.so\h+([^#\n\r]+\h+)?use_authtok\b" \
   /etc/pam.d/common-password 2>/dev/null | grep -q .; then
    echo -e "${GREEN}HARDENED${RESET}"
else
    echo -e "${RED}NOT HARDENED${RESET}"
fi

exit 0
