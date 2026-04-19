#!/usr/bin/env bash

NAME='sshd GSSAPIAuthentication set to no'
SEVERITY='basic'

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

[ -f "$PERM_RAM_STORE" ] && source "$PERM_RAM_STORE"

EXPECTED="${SSHD_GSSAPIAUTHENTICATION_EXPECTED:-no}"

value=$(sshd -T 2>/dev/null | awk '/^gssapiauthentication/ {print $2}')

if [[ "$value" == "$EXPECTED" ]]; then
    echo -e "${GREEN}HARDENED${RESET}"
else
    echo -e "${RED}NOT HARDENED${RESET}"
fi

exit 0
