#!/usr/bin/env bash

NAME="/etc/passwd accounts use shadowed passwords"
SEVERITY="basic"

FILE="/etc/passwd"

# File must exist
[ -f "$FILE" ] || exit 2

# Run awk check
output=$(awk -F: '($2 != "x") { print "User: \"" $1 "\" is not set to shadowed passwords" }' "$FILE")

if [[ -z "$output" ]]; then
    echo -e "${GREEN}HARDENED${RESET}"
else
    echo -e "${RED}NOT HARDENED${RESET}"
    echo "$output"
fi

exit 0
