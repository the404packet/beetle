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

# Direct shadow update for all active accounts
awk -F: -v min="$MIN_DAYS" 'BEGIN{OFS=":"} {if ($2 !~ /^[*!]/ && ($4 < min || $4 == "")) $4=min; print}' /etc/shadow > /etc/shadow.tmp && cat /etc/shadow.tmp > /etc/shadow && rm -f /etc/shadow.tmp 2>/dev/null || true

# Run chage for all non-system users
for user in $(awk -F: '($2 !~ /^[*!]/) {print $1}' /etc/shadow 2>/dev/null); do
    [ -n "$user" ] || continue
    chage --mindays "$MIN_DAYS" "$user" 2>/dev/null || true
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
