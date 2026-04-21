#!/usr/bin/env bash

NAME='ensure pam_faillock module is enabled'
SEVERITY='basic'

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

flag=1

# Check common-auth has both preauth and authfail lines
if ! grep -P -- '\bpam_faillock\.so\b' /etc/pam.d/common-auth 2>/dev/null | grep -q 'preauth'; then
    flag=0
fi
if ! grep -P -- '\bpam_faillock\.so\b' /etc/pam.d/common-auth 2>/dev/null | grep -q 'authfail'; then
    flag=0
fi

# Check common-account has pam_faillock
if ! grep -P -- '\bpam_faillock\.so\b' /etc/pam.d/common-account 2>/dev/null | grep -q .; then
    flag=0
fi

if (( flag )); then
    echo -e "${GREEN}HARDENED${RESET}"
else
    echo -e "${RED}NOT HARDENED${RESET}"
fi

exit 0
