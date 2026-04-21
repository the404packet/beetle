#!/usr/bin/env bash

NAME='ensure root account access is controlled'
SEVERITY='basic'

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

# Root password must be set (P) or locked (L)
status=$(passwd -S root 2>/dev/null | awk '{print $2}')

if [[ "$status" == "P" || "$status" == "L" ]]; then
    echo -e "${GREEN}HARDENED${RESET}"
else
    echo -e "${RED}NOT HARDENED${RESET}"
fi

exit 0
