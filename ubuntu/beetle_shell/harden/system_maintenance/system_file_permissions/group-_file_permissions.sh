#!/usr/bin/env bash

NAME="/etc/group- backup file permissions"
SEVERITY="basic"

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

FILE="/etc/group-"

# If backup file does not exist, treat as compliant
[ -e "$FILE" ] || exit 0

# Must be a regular file
[ -f "$FILE" ] || exit 2

if chmod u-x,go-wx "$FILE" && chown root:root "$FILE"; then
    echo -e "${GREEN}HARDENED - SUCCESS${RESET}"
else
    echo -e "${RED}HARDENED - FAILED${RESET}"
    exit 1
fi

exit 0