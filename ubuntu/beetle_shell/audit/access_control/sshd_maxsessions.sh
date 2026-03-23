#!/usr/bin/env bash

NAME='sshd maxsessions config'
SEVERITY="basic"

value=$(sshd -T 2>/dev/null | awk '/^maxsessions/ {print $2}')

if [[ "$value" =~ ^[0-9]+$ ]] && (( value <= 10 )); then
    echo -e "${GREEN}HARDENED${RESET}"
else
    echo -e "${RED}NOT HARDENED${RESET}"
fi

exit 0