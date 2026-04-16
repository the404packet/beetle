#!/usr/bin/env bash

NAME="/etc/shadow empty password check"
SEVERITY="basic"

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

FILE="/etc/shadow"

[ -f "$FILE" ] || exit 2

# Find all accounts with empty passwords
empty_accounts=$(awk -F: '($2 == "") { print $1 }' "$FILE")

if [[ -z "$empty_accounts" ]]; then
    echo -e "${GREEN}SUCCESS${RESET}"
else
    FAILED=0
    while IFS= read -r account; do
        passwd -l "$account" 2>/dev/null || FAILED=1
    done <<< "$empty_accounts"

    if [[ "$FAILED" -eq 0 ]]; then
        echo -e "${GREEN}SUCCESS${RESET}"
    else
        echo -e "${RED}FAILED${RESET}"
        exit 1
    fi
fi

exit 0