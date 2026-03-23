#!/usr/bin/env bash

NAME='sshd MaxAuthTries config'
SEVERITY="basic"

value=$(sshd -T 2>/dev/null | awk '/^maxauthtries/ {print $2}')

if [[ "$value" =~ ^[0-9]+$ ]] && (( value <= 4 )); then
    echo -e "${GREEN}HARDENED${RESET}"
else
    echo -e "${RED}NOT HARDENED${RESET}"
fi

exit 0