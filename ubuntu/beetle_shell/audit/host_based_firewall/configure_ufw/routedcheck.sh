#!/usr/bin/env bash

NAME='ufw routed check'
SEVERITY="basic"

flag=1

if ! ufw status verbose | grep -q "deny (routed)"; then
    flag=0
fi

if (( flag )); then
    echo -e "${GREEN}HARDENED${RESET}"
else
    echo -e "${RED}NOT HARDENED${RESET}"
fi

exit 0
