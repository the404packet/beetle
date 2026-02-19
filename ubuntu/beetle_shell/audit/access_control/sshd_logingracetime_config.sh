#!/usr/bin/env bash

NAME='sshd logingracetime config'
SEVERITY="basic"


value=$(sshd -T 2>/dev/null | awk '/^logingracetime/ {print $2}')

if [[ "$value" =~ ^[0-9]+$ ]] && (( value > 0 && value <= 60 )); then
    echo -e "${GREEN}HARDENED${RESET}"
else
    echo -e "${RED}NOT HARDENED${RESET}"
fi
