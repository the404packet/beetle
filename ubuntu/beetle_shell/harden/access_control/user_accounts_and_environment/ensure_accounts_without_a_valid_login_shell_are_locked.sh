#!/usr/bin/env bash

NAME='ensure accounts without a valid login shell are locked'
SEVERITY='basic'

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

l_valid_shells="^($(awk -F/ '$NF != "nologin" {print}' /etc/shells 2>/dev/null \
    | sed -rn '/^\//{ s,/,\\\\/,g; p }' \
    | paste -s -d '|' - ))$"

# Lock any non-root account without a valid login shell that is not already locked
while IFS= read -r l_user; do
    passwd -S "$l_user" 2>/dev/null | awk '$2 !~ /^L/ {print $1}' | while IFS= read -r unlocked; do
        usermod -L "$unlocked"
    done
done < <(awk -v pat="$l_valid_shells" -F: \
    '($1 != "root" && $(NF) !~ pat) {print $1}' /etc/passwd 2>/dev/null)

# Validate
flag=1
while IFS= read -r l_user; do
    bad=$(passwd -S "$l_user" 2>/dev/null | awk '$2 !~ /^L/ {print $1}')
    [[ -n "$bad" ]] && flag=0
done < <(awk -v pat="$l_valid_shells" -F: \
    '($1 != "root" && $(NF) !~ pat) {print $1}' /etc/passwd 2>/dev/null)

if (( flag )); then
    echo -e "${GREEN}SUCCESS${RESET}"
    exit 0
else
    echo -e "${RED}FAILED${RESET}"
    exit 1
fi
