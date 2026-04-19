#!/usr/bin/env bash

NAME='sshd MaxSessions config'
SEVERITY='basic'

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

[ -f "$PERM_RAM_STORE" ] && source "$PERM_RAM_STORE"

MAX_SESSIONS="${SSHD_MAXSESSIONS_MAX:-10}"

value=$(sshd -T 2>/dev/null | awk '/^maxsessions/ {print $2}')

if [[ "$value" =~ ^[0-9]+$ ]] && (( value <= MAX_SESSIONS )); then
    echo -e "${GREEN}HARDENED${RESET}"
else
    echo -e "${RED}NOT HARDENED${RESET}"
fi

exit 0
