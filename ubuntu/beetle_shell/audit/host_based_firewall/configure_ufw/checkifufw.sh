#!/usr/bin/env bash

NAME='ufw install check'
SEVERITY="basic"

flag=1

if ! command -v ufw >/dev/null 2>&1; then
    flag=0
fi

if (( flag )); then
    echo -e "${GREEN}HARDENED${RESET}"
else
    echo -e "${RED}NOT HARDENED${RESET}"
fi

exit 0
