#!/usr/bin/env bash

NAME="ensure minimum password days is configured"
SEVERITY='basic'

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

[ -f "$SSH_RAM_STORE" ] && source "$SSH_RAM_STORE"

MIN_DAYS="${LD_pass_min_days_min:-1}"
LOGIN_DEFS="${LD_file:-/etc/login.defs}"

# Update /etc/login.defs
if grep -Piq '^\h*PASS_MIN_DAYS\h+\d+\b' "$LOGIN_DEFS" 2>/dev/null; then
    sed -i "s|^\h*PASS_MIN_DAYS\h.*|PASS_MIN_DAYS ${MIN_DAYS}|" "$LOGIN_DEFS"
else
    echo "PASS_MIN_DAYS ${MIN_DAYS}" >> "$LOGIN_DEFS"
fi

# Apply to all existing users with a password whose PASS_MIN_DAYS is below minimum
awk -F: -v min="$MIN_DAYS" \
    '($2~/^\$.+\$/) {if($4 < min) print $1}' \
    /etc/shadow 2>/dev/null | while IFS= read -r user; do
    chage --mindays "$MIN_DAYS" "$user"
done

# Validate
flag=1
val=$(grep -Pi -- '^\h*PASS_MIN_DAYS\h+\d+\b' "$LOGIN_DEFS" 2>/dev/null \
    | awk '{print $2}' | head -1)
if [[ -z "$val" ]] || (( val < MIN_DAYS )); then
    flag=0
fi

while IFS= read -r bad_user; do
    [[ -n "$bad_user" ]] && flag=0
done < <(awk -F: -v min="$MIN_DAYS" \
    '($2~/^\$.+\$/) {if($4 < min) print $1}' /etc/shadow 2>/dev/null)

if (( flag )); then
    echo -e "${GREEN}SUCCESS${RESET}"
    exit 0
else
    echo -e "${RED}FAILED${RESET}"
    exit 1
fi
