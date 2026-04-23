#!/usr/bin/env bash

NAME="ensure group root is the only GID 0 group"
SEVERITY='basic'

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

result=$(awk -F: '$3=="0"{print $1":"$3}' /etc/group 2>/dev/null)

non_root=$(echo "$result" | grep -v '^root:0$')
has_root=$(echo "$result" | grep -c '^root:0$')

if [[ -z "$non_root" ]] && (( has_root == 1 )); then
    echo -e "${GREEN}HARDENED${RESET}"
else
    echo -e "${RED}NOT HARDENED${RESET}"
fi

exit 0
