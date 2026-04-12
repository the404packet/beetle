#!/usr/bin/env bash

NAME="/etc/group file permissions"
SEVERITY="basic"

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

FILE="/etc/group"

[ -f "$FILE" ] || exit 2

if chmod u-x,go-wx "$FILE" && chown root:root "$FILE"; then
    echo -e "${GREEN}HARDENED - SUCCESS${RESET}"
else
    echo -e "${RED}HARDENED - FAILED${RESET}"
    exit 1
fi

exit 0