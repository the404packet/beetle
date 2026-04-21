#!/usr/bin/env bash

NAME='ensure root is the only GID 0 account'
SEVERITY='basic'

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

# root must have GID 0; sync/shutdown/halt/operator are exempt from the "others" check
result=$(awk -F: '($1 !~ /^(sync|shutdown|halt|operator)$/ && $4=="0") {print $1":"$4}' \
    /etc/passwd 2>/dev/null)

# Should only be "root:0"
non_root=$(echo "$result" | grep -v '^root:0$')
has_root=$(echo "$result" | grep -c '^root:0$')

if [[ -z "$non_root" ]] && (( has_root == 1 )); then
    echo -e "${GREEN}HARDENED${RESET}"
else
    echo -e "${RED}NOT HARDENED${RESET}"
fi

exit 0
