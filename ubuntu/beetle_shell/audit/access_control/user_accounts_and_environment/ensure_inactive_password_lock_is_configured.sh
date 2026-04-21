#!/usr/bin/env bash

NAME='ensure inactive password lock is configured'
SEVERITY='basic'

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

[ -f "$SSH_RAM_STORE" ] && source "$SSH_RAM_STORE"

MAX_INACTIVE="${LD_inactive_max:-45}"

flag=1

# Check useradd default INACTIVE
inactive_val=$(useradd -D 2>/dev/null | grep -i INACTIVE | cut -d= -f2 | xargs)
if [[ -z "$inactive_val" ]] || (( inactive_val < 0 || inactive_val > MAX_INACTIVE )); then
    flag=0
fi

# Check all shadow users with a password
while IFS= read -r bad_user; do
    [[ -n "$bad_user" ]] && flag=0
done < <(awk -F: -v max="$MAX_INACTIVE" \
    '($2~/^\$.+\$/) {if($7 > max || $7 < 0) print "User: " $1 " INACTIVE: " $7}' \
    /etc/shadow 2>/dev/null)

if (( flag )); then
    echo -e "${GREEN}HARDENED${RESET}"
else
    echo -e "${RED}NOT HARDENED${RESET}"
fi

exit 0
