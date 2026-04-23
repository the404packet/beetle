#!/usr/bin/env bash

NAME="ensure password expiration is configured"
SEVERITY='basic'

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

[ -f "$SSH_RAM_STORE" ] && source "$SSH_RAM_STORE"

MAX_DAYS="${LD_pass_max_days_max:-365}"
LOGIN_DEFS="${LD_file:-/etc/login.defs}"

flag=1

# Check /etc/login.defs PASS_MAX_DAYS is set and <= MAX_DAYS
val=$(grep -Pi -- '^\h*PASS_MAX_DAYS\h+\d+\b' "$LOGIN_DEFS" 2>/dev/null \
    | awk '{print $2}' | head -1)
if [[ -z "$val" ]] || (( val < 1 || val > MAX_DAYS )); then
    flag=0
fi

# Check all shadow users with a password have conforming PASS_MAX_DAYS
while IFS= read -r bad_user; do
    [[ -n "$bad_user" ]] && flag=0
done < <(awk -F: -v max="$MAX_DAYS" \
    '($2~/^\$.+\$/) {if($5 > max || $5 < 1) print "User: " $1 " PASS_MAX_DAYS: " $5}' \
    /etc/shadow 2>/dev/null)

if (( flag )); then
    echo -e "${GREEN}HARDENED${RESET}"
else
    echo -e "${RED}NOT HARDENED${RESET}"
fi

exit 0
