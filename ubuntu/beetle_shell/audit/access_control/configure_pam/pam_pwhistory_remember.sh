#!/usr/bin/env bash

NAME='ensure password history remember is configured'
SEVERITY='basic'

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

[ -f "$SSH_RAM_STORE" ] && source "$SSH_RAM_STORE"

MIN_REMEMBER="${PAM_PWHISTORY_REMEMBER_MIN:-24}"

if grep -Psi -- "^\h*password\h+[^#\n\r]+\h+pam_pwhistory\.so\h+([^#\n\r]+\h+)?remember=\d+\b" \
   /etc/pam.d/common-password 2>/dev/null | \
   awk -F'remember=' '{print $2}' | awk '{print $1}' | \
   grep -qP "^([${MIN_REMEMBER}-9]|[1-9][0-9]+)$"; then
    echo -e "${GREEN}HARDENED${RESET}"
else
    echo -e "${RED}NOT HARDENED${RESET}"
fi

exit 0
