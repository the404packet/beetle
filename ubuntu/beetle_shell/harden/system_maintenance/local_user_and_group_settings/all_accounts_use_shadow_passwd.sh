#!/usr/bin/env bash

NAME="/etc/passwd accounts use shadowed passwords"
SEVERITY="basic"

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

FILE="/etc/passwd"

[ -f "$FILE" ] || exit 2

if pwconv 2>/dev/null; then
    echo -e "${GREEN}SUCCESS${RESET}"
else
    echo -e "${RED}FAILED${RESET}"
    exit 1
fi

exit 0