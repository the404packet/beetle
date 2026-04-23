#!/usr/bin/env bash

NAME="ensure nosuid option set on /var partition"

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

[ -f "$INITIAL_SETUP_RAM_STORE" ] && source "$INITIAL_SETUP_RAM_STORE"

if ! is_partition_mounted "/var"; then
    echo -e "${GREEN}HARDENED${RESET}"
    exit 0
fi

if findmnt -kn "/var" | grep -qv "nosuid"; then
    echo -e "${RED}NOT HARDENED${RESET}"
else
    echo -e "${GREEN}HARDENED${RESET}"
fi

exit 0