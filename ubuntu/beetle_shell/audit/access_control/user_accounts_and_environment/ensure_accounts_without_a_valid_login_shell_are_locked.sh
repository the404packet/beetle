#!/usr/bin/env bash

NAME="ensure accounts without a valid login shell are locked"
SEVERITY='basic'

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

l_valid_shells="^($(awk -F/ '$NF != "nologin" {print}' /etc/shells 2>/dev/null \
    | sed -rn '/^\//{ s,/,\\\\/,g; p }' \
    | paste -s -d '|' - ))$"

flag=1

while IFS= read -r l_user; do
    bad=$(passwd -S "$l_user" 2>/dev/null | awk '$2 !~ /^L/ {print $1}')
    [[ -n "$bad" ]] && flag=0
done < <(awk -v pat="$l_valid_shells" -F: \
    '($1 != "root" && $(NF) !~ pat) {print $1}' /etc/passwd 2>/dev/null)

if (( flag )); then
    echo -e "${GREEN}HARDENED${RESET}"
else
    echo -e "${RED}NOT HARDENED${RESET}"
fi

exit 0
