#!/usr/bin/env bash

NAME='sshd loglevel config'
SEVERITY="basic"

value=$(sshd -T 2>/dev/null | awk '/^loglevel/ {print tolower($2)}')

if [[ "$value" == "info" || "$value" == "verbose" ]]; then
    echo -e "${GREEN}HARDENED${RESET}"
else
    echo -e "${RED}NOT HARDENED${RESET}"
fi
