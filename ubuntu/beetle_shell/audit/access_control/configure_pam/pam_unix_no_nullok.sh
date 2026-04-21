#!/usr/bin/env bash

NAME='ensure pam_unix does not include nullok'
SEVERITY='basic'

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

flag=1

for context in password auth account session session-noninteractive; do
    file="/etc/pam.d/common-${context}"
    [ -f "$file" ] || continue
    if grep -PH -- '^\h*[^#\n\r]+\h+pam_unix\.so\b' "$file" 2>/dev/null | grep -Pq '\bnullok\b'; then
        flag=0
        break
    fi
done

if (( flag )); then
    echo -e "${GREEN}HARDENED${RESET}"
else
    echo -e "${RED}NOT HARDENED${RESET}"
fi

exit 0
