#!/usr/bin/env bash

NAME="ensure accounts without a valid login shell are locked"
SEVERITY='basic'

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

uid_min=$(awk '/^\s*UID_MIN/{print $2}' /etc/login.defs 2>/dev/null)
uid_min="${uid_min:-1000}"

l_valid_shells="^($(awk -F/ '$NF != "nologin" {print}' /etc/shells 2>/dev/null \
    | sed -rn '/^\//{ s,/,\\\\/,g; p }' \
    | paste -s -d '|' - ))$"

while IFS= read -r l_user; do
    passwd -S "$l_user" 2>/dev/null | awk '$2 !~ /^L/ {print $1}' | while IFS= read -r unlocked; do
        usermod -L "$unlocked" &>/dev/null
    done
done < <(awk -v pat="$l_valid_shells" -v uid_min="$uid_min" -F: \
    '($1 != "root" && $3 < uid_min && $(NF) !~ pat) {print $1}' /etc/passwd 2>/dev/null)

flag=1
while IFS= read -r l_user; do
    bad=$(passwd -S "$l_user" 2>/dev/null | awk '$2 !~ /^L/ {print $1}')
    [[ -n "$bad" ]] && flag=0
done < <(awk -v pat="$l_valid_shells" -v uid_min="$uid_min" -F: \
    '($1 != "root" && $3 < uid_min && $(NF) !~ pat) {print $1}' /etc/passwd 2>/dev/null)

if (( flag )); then
    echo -e "${GREEN}SUCCESS${RESET}"
    exit 0
else
    echo -e "${RED}FAILED${RESET}"
    exit 1
fi