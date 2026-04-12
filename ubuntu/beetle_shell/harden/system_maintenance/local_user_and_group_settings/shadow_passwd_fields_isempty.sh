#!/usr/bin/env bash

NAME="/etc/shadow empty password check"
SEVERITY="basic"

FILE="/etc/shadow"

# File must exist
[ -f "$FILE" ] || exit 2

# Run awk check
output=$(awk -F: '($2 == "" ) { print $1 " does not have a password" }' "$FILE")

if [[ -z "$output" ]]; then
    echo -e "${GREEN}HARDENED${RESET}"
else
    echo -e "${RED}NOT HARDENED${RESET}"
    echo "$output"
fi

exit 0
