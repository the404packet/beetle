#!/usr/bin/env bash

NAME='ensure all users last password change date is in the past'
SEVERITY='basic'

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

flag=1
now=$(date +%s)

while IFS= read -r l_user; do
    change_str=$(chage --list "$l_user" 2>/dev/null \
        | grep '^Last password change' \
        | cut -d: -f2 \
        | sed 's/^ *//' \
        | grep -v 'never$')
    [ -z "$change_str" ] && continue
    l_change=$(date -d "$change_str" +%s 2>/dev/null) || continue
    if (( l_change > now )); then
        flag=0
    fi
done < <(awk -F: '$2~/^\$.+\$/{print $1}' /etc/shadow 2>/dev/null)

if (( flag )); then
    echo -e "${GREEN}HARDENED${RESET}"
else
    echo -e "${RED}NOT HARDENED${RESET}"
fi

exit 0
