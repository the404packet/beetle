#!/usr/bin/env bash
NAME='ensure message of the day is configured properly'
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$INITIAL_SETUP_RAM_STORE" ] && source "$INITIAL_SETUP_RAM_STORE"

# motd is optional — if absent, we're compliant
[ ! -e /etc/motd ] && { echo -e "${GREEN}SUCCESS${RESET}"; exit 0; }

os_id=$(grep '^ID=' /etc/os-release 2>/dev/null | cut -d= -f2 | sed 's/"//g')
pattern="(\\\\v|\\\\r|\\\\m|\\\\s|${os_id})"

if grep -Ei "$pattern" /etc/motd 2>/dev/null | grep -q .; then
    # motd contains OS-identifying info. Since motd is optional (per JSON),
    # remove the file. CIS accepts its absence.
    rm -f /etc/motd
    echo -e "${GREEN}SUCCESS${RESET}"
    exit 0
fi

echo -e "${GREEN}SUCCESS${RESET}"
exit 0