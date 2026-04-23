#!/usr/bin/env bash

NAME="ensure password expiration warning days is configured"
SEVERITY='basic'

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

[ -f "$SSH_RAM_STORE" ] && source "$SSH_RAM_STORE"

WARN_AGE="${LD_pass_warn_age_min:-7}"
LOGIN_DEFS="${LD_file:-/etc/login.defs}"

flag=1

# Check /etc/login.defs PASS_WARN_AGE is set and >= WARN_AGE
val=$(grep -Pi -- '^\h*PASS_WARN_AGE\h+\d+\b' "$LOGIN_DEFS" 2>/dev/null \
    | awk '{print $2}' | head -1)
if [[ -z "$val" ]] || (( val < WARN_AGE )); then
    flag=0
fi

# Check all shadow users with a password have PASS_WARN_AGE >= WARN_AGE
while IFS= read -r bad_user; do
    [[ -n "$bad_user" ]] && flag=0
done < <(awk -F: -v warn="$WARN_AGE" \
    '($2~/^\$.+\$/) {if($6 < warn) print "User: " $1 " PASS_WARN_AGE: " $6}' \
    /etc/shadow 2>/dev/null)

if (( flag )); then
    echo -e "${GREEN}HARDENED${RESET}"
else
    echo -e "${RED}NOT HARDENED${RESET}"
fi

exit 0
