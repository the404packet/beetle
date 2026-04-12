#!/usr/bin/env bash

NAME='ufw incoming check'
SEVERITY="basic"

flag=1

if ! ufw status verbose | grep -q "Default: deny (incoming)"; then
    flag=0
fi

if (( flag )); then
    echo -e "${GREEN}HARDENED${RESET}"
else
    echo -e "${RED}NOT HARDENED${RESET}"
fi

exit 0
