#!/usr/bin/env bash

NAME='ensure nologin is not listed in /etc/shells'
SEVERITY='basic'

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

# Remove any lines containing a path ending in /nologin from /etc/shells
if grep -Ps '^\h*([^#\n\r]+)?\/nologin\b' /etc/shells >/dev/null 2>&1; then
    sed -i -E '/^\h*([^#].*)?\/nologin\b/d' /etc/shells
fi

# Validate
if grep -Ps '^\h*([^#\n\r]+)?\/nologin\b' /etc/shells >/dev/null 2>&1; then
    echo -e "${RED}FAILED${RESET}"
    exit 1
else
    echo -e "${GREEN}SUCCESS${RESET}"
    exit 0
fi
