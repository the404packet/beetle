#!/usr/bin/env bash

NAME='ensure password quality checking is enforced'
SEVERITY='basic'

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

flag=1

# enforcing=0 must NOT appear in config files
if grep -PHsi -- "^\h*enforcing\h*=\h*0\b" \
   /etc/security/pwquality.conf /etc/security/pwquality.conf.d/*.conf 2>/dev/null | grep -q .; then
    flag=0
fi

# enforcing=0 must NOT appear as pam argument
if grep -PHsi -- "^\h*password\h+[^#\n\r]+\h+pam_pwquality\.so\h+([^#\n\r]+\h+)?enforcing=0\b" \
   /etc/pam.d/common-password 2>/dev/null | grep -q .; then
    flag=0
fi

if (( flag )); then
    echo -e "${GREEN}HARDENED${RESET}"
else
    echo -e "${RED}NOT HARDENED${RESET}"
fi

exit 0
