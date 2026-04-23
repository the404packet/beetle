#!/usr/bin/env bash

NAME="ensure group root is the only GID 0 group"
SEVERITY='basic'

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

# Ensure group root has GID 0
groupmod -g 0 root 2>/dev/null

# Flag any other group with GID 0 — cannot safely auto-reassign GID
flag=1
while IFS= read -r entry; do
    grp="${entry%%:*}"
    [[ "$grp" == "root" ]] && continue
    echo "WARNING: Group \"$grp\" has GID 0 and must be manually reassigned" >&2
    flag=0
done < <(awk -F: '$3=="0"{print $1":"$3}' /etc/group 2>/dev/null)

if (( flag )); then
    echo -e "${GREEN}SUCCESS${RESET}"
    exit 0
else
    echo -e "${RED}FAILED${RESET}"
    exit 1
fi
