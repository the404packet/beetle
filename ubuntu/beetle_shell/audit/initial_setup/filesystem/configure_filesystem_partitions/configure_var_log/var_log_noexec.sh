#!/usr/bin/env bash

NAME="ensure noexec option set on /var/log partition"

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

[ -f "$INITIAL_SETUP_RAM_STORE" ] && source "$INITIAL_SETUP_RAM_STORE"

if ! is_partition_mounted "/var/log"; then
    echo -e "${GREEN}HARDENED${RESET}"
    exit 0
fi

if findmnt -kn "/var/log" | grep -qv "noexec"; then
    echo -e "${RED}NOT HARDENED${RESET}"
else
    echo -e "${GREEN}HARDENED${RESET}"
fi

exit 0