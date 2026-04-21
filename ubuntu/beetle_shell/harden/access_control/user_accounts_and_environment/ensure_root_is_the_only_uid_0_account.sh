#!/usr/bin/env bash

NAME='ensure root is the only UID 0 account'
SEVERITY='basic'

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

# Ensure root itself has UID 0
usermod -u 0 root 2>/dev/null

# Any non-root account with UID 0 cannot be safely auto-reassigned without
# knowing what UID to use — log them and fail so the operator resolves manually.
flag=1
while IFS= read -r extra; do
    [[ "$extra" == "root" ]] && continue
    echo "WARNING: Account \"$extra\" has UID 0 and must be manually reassigned" >&2
    flag=0
done < <(awk -F: '($3 == 0) {print $1}' /etc/passwd 2>/dev/null)

if (( flag )); then
    echo -e "${GREEN}SUCCESS${RESET}"
    exit 0
else
    echo -e "${RED}FAILED${RESET}"
    exit 1
fi
