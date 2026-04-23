#!/usr/bin/env bash

NAME="ensure root is the only GID 0 account"
SEVERITY='basic'

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

# Ensure root's primary GID is 0
usermod -g 0 root >/dev/null 2>&1

# Flag any other non-exempt accounts with primary GID 0 — cannot safely auto-fix
flag=1
while IFS= read -r acct; do
    user="${acct%%:*}"
    echo "WARNING: Account \"$user\" has primary GID 0 and must be manually reassigned" >&2
    flag=0
done < <(awk -F: '($1 !~ /^(root|sync|shutdown|halt|operator)$/ && $4=="0") {print $1":"$4}' \
    /etc/passwd 2>/dev/null | grep -v '^root:0$')

if (( flag )); then
    echo -e "${GREEN}SUCCESS${RESET}"
    exit 0
else
    echo -e "${RED}FAILED${RESET}"
    exit 1
fi
