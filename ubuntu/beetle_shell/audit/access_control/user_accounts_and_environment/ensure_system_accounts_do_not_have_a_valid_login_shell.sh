#!/usr/bin/env bash

NAME='ensure system accounts do not have a valid login shell'
SEVERITY='basic'

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

uid_min=$(awk '/^\s*UID_MIN/{print $2}' /etc/login.defs 2>/dev/null)
uid_min="${uid_min:-1000}"

l_valid_shells="^($(awk -F/ '$NF != "nologin" {print}' /etc/shells 2>/dev/null \
    | sed -rn '/^\//{ s,/,\\\\/,g; p }' \
    | paste -s -d '|' - ))$"

bad=$(awk -v pat="$l_valid_shells" -v uid_min="$uid_min" -F: \
    '($1!~/^(root|halt|sync|shutdown|nfsnobody)$/ && ($3 < uid_min || $3 == 65534) && $(NF) ~ pat) \
    {print "Service account: \"" $1 "\" has a valid shell: " $7}' \
    /etc/passwd 2>/dev/null)

if [[ -z "$bad" ]]; then
    echo -e "${GREEN}HARDENED${RESET}"
else
    echo -e "${RED}NOT HARDENED${RESET}"
fi

exit 0
