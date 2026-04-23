#!/usr/bin/env bash

NAME="ensure nodev option set on /home partition"

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

[ -f "$INITIAL_SETUP_RAM_STORE" ] && source "$INITIAL_SETUP_RAM_STORE"

if ! is_partition_mounted "/home"; then
    echo -e "${GREEN}HARDENED${RESET}"
    exit 0
fi

if findmnt -kn "/home" | grep -qv "nodev"; then
    echo -e "${RED}NOT HARDENED${RESET}"
else
    echo -e "${GREEN}HARDENED${RESET}"
fi

exit 0