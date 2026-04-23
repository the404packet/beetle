#!/usr/bin/env bash
NAME='ensure message of the day is configured properly'
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$INITIAL_SETUP_RAM_STORE" ] && source "$INITIAL_SETUP_RAM_STORE"

# motd is optional — if absent, pass
[ ! -e /etc/motd ] && { echo -e "${GREEN}HARDENED${RESET}"; exit 0; }

os_id=$(grep '^ID=' /etc/os-release 2>/dev/null | cut -d= -f2 | sed 's/"//g')
pattern="(\\\\v|\\\\r|\\\\m|\\\\s|${os_id})"

grep -Ei "$pattern" /etc/motd 2>/dev/null | grep -q . \
    && echo -e "${RED}NOT HARDENED${RESET}" \
    || echo -e "${GREEN}HARDENED${RESET}"
exit 0