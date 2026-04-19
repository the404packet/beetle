#!/usr/bin/env bash

NAME='sshd LoginGraceTime config'
SEVERITY='basic'

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

[ -f "$PERM_RAM_STORE" ] && source "$PERM_RAM_STORE"

GRACE_MIN="${SSHD_LOGINGRACETIME_MIN:-1}"
GRACE_MAX="${SSHD_LOGINGRACETIME_MAX:-60}"

value=$(sshd -T 2>/dev/null | awk '/^logingracetime/ {print $2}')

if [[ "$value" =~ ^[0-9]+$ ]] && (( value >= GRACE_MIN && value <= GRACE_MAX )); then
    echo -e "${GREEN}HARDENED${RESET}"
else
    echo -e "${RED}NOT HARDENED${RESET}"
fi

exit 0
