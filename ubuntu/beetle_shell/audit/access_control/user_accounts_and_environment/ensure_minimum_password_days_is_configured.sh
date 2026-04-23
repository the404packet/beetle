#!/usr/bin/env bash

NAME="ensure minimum password days is configured"
SEVERITY='basic'

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

[ -f "$SSH_RAM_STORE" ] && source "$SSH_RAM_STORE"

MIN_DAYS="${LD_pass_min_days_min:-1}"
LOGIN_DEFS="${LD_file:-/etc/login.defs}"

flag=1

# Check /etc/login.defs PASS_MIN_DAYS is set and >= MIN_DAYS
val=$(grep -Pi -- '^\h*PASS_MIN_DAYS\h+\d+\b' "$LOGIN_DEFS" 2>/dev/null \
    | awk '{print $2}' | head -1)
if [[ -z "$val" ]] || (( val < MIN_DAYS )); then
    flag=0
fi

# Check all shadow users with a password have PASS_MIN_DAYS >= MIN_DAYS
while IFS= read -r bad_user; do
    [[ -n "$bad_user" ]] && flag=0
done < <(awk -F: -v min="$MIN_DAYS" \
    '($2~/^\$.+\$/) {if($4 < min) print "User: " $1 " PASS_MIN_DAYS: " $4}' \
    /etc/shadow 2>/dev/null)

if (( flag )); then
    echo -e "${GREEN}HARDENED${RESET}"
else
    echo -e "${RED}NOT HARDENED${RESET}"
fi

exit 0
