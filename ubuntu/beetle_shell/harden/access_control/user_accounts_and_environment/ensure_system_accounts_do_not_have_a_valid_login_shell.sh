#!/usr/bin/env bash

NAME="ensure system accounts do not have a valid login shell"
SEVERITY='basic'

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

nologin_path=$(command -v nologin)
if [[ -z "$nologin_path" ]]; then
    echo "ERROR: nologin binary not found" >&2
    echo -e "${RED}FAILED${RESET}"
    exit 1
fi

uid_min=$(awk '/^\s*UID_MIN/{print $2}' /etc/login.defs 2>/dev/null)
uid_min="${uid_min:-1000}"

l_valid_shells="^($(awk -F/ '$NF != "nologin" {print}' /etc/shells 2>/dev/null \
    | sed -rn '/^\//{ s,/,\\\\/,g; p }' \
    | paste -s -d '|' - ))$"

# Set shell to nologin for any system account that has a valid login shell
awk -v pat="$l_valid_shells" -v uid_min="$uid_min" -F: \
    '($1!~/^(root|halt|sync|shutdown|nfsnobody)$/ && ($3 < uid_min || $3 == 65534) && $(NF) ~ pat) \
    {print $1}' /etc/passwd 2>/dev/null | while IFS= read -r user; do
    usermod -s "$nologin_path" "$user"
done

# Validate
bad=$(awk -v pat="$l_valid_shells" -v uid_min="$uid_min" -F: \
    '($1!~/^(root|halt|sync|shutdown|nfsnobody)$/ && ($3 < uid_min || $3 == 65534) && $(NF) ~ pat) \
    {print $1}' /etc/passwd 2>/dev/null)

if [[ -z "$bad" ]]; then
    echo -e "${GREEN}SUCCESS${RESET}"
    exit 0
else
    echo -e "${RED}FAILED${RESET}"
    exit 1
fi
