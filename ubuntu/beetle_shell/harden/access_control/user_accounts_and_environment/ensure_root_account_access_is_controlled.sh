#!/usr/bin/env bash

NAME='ensure root account access is controlled'
SEVERITY='basic'

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

status=$(passwd -S root 2>/dev/null | awk '{print $2}')

if [[ "$status" == "P" || "$status" == "L" ]]; then
    # Already compliant — nothing to do
    echo -e "${GREEN}SUCCESS${RESET}"
    exit 0
fi

# Password is in an unknown/NP state — lock the account to make it compliant.
# An operator can later set a password with: passwd root
usermod -L root

# Validate
status=$(passwd -S root 2>/dev/null | awk '{print $2}')
if [[ "$status" == "P" || "$status" == "L" ]]; then
    echo -e "${GREEN}SUCCESS${RESET}"
    exit 0
else
    echo -e "${RED}FAILED${RESET}"
    exit 1
fi
