#!/usr/bin/env bash

NAME='ensure root is the only UID 0 account'
SEVERITY='basic'

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

uid0_accounts=$(awk -F: '($3 == 0) {print $1}' /etc/passwd 2>/dev/null)

# Only "root" should appear
non_root=$(echo "$uid0_accounts" | grep -v '^root$')

if [[ -z "$non_root" ]] && echo "$uid0_accounts" | grep -q '^root$'; then
    echo -e "${GREEN}HARDENED${RESET}"
else
    echo -e "${RED}NOT HARDENED${RESET}"
fi

exit 0
