#!/usr/bin/env bash
NAME='ensure local login warning banner is configured properly'
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$INITIAL_SETUP_RAM_STORE" ] && source "$INITIAL_SETUP_RAM_STORE"

os_id=$(grep '^ID=' /etc/os-release 2>/dev/null | cut -d= -f2 | sed 's/"//g')
pattern="(\\\\v|\\\\r|\\\\m|\\\\s|${os_id})"

grep -Ei "$pattern" /etc/issue 2>/dev/null | grep -q . \
    && echo -e "${RED}NOT HARDENED${RESET}" \
    || echo -e "${GREEN}HARDENED${RESET}"
exit 0