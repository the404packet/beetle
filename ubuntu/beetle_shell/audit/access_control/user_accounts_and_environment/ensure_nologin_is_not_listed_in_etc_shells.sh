#!/usr/bin/env bash

NAME='ensure nologin is not listed in /etc/shells'
SEVERITY='basic'

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

if grep -Ps '^\h*([^#\n\r]+)?\/nologin\b' /etc/shells >/dev/null 2>&1; then
    echo -e "${RED}NOT HARDENED${RESET}"
else
    echo -e "${GREEN}HARDENED${RESET}"
fi

exit 0
