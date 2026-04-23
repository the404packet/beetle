#!/usr/bin/env bash

NAME="ensure password expiration warning days is configured"
SEVERITY='basic'

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

[ -f "$SSH_RAM_STORE" ] && source "$SSH_RAM_STORE"

WARN_AGE="${LD_pass_warn_age_min:-7}"
LOGIN_DEFS="${LD_file:-/etc/login.defs}"

# Update /etc/login.defs
if grep -Piq '^\h*PASS_WARN_AGE\h+\d+\b' "$LOGIN_DEFS" 2>/dev/null; then
    sed -i "s|^\h*PASS_WARN_AGE\h.*|PASS_WARN_AGE ${WARN_AGE}|" "$LOGIN_DEFS"
else
    echo "PASS_WARN_AGE ${WARN_AGE}" >> "$LOGIN_DEFS"
fi

# Apply to all existing users with a password whose PASS_WARN_AGE is below minimum
awk -F: -v warn="$WARN_AGE" \
    '($2~/^\$.+\$/) {if($6 < warn) print $1}' \
    /etc/shadow 2>/dev/null | while IFS= read -r user; do
    chage --warndays "$WARN_AGE" "$user"
done

# Validate
flag=1
val=$(grep -Pi -- '^\h*PASS_WARN_AGE\h+\d+\b' "$LOGIN_DEFS" 2>/dev/null \
    | awk '{print $2}' | head -1)
if [[ -z "$val" ]] || (( val < WARN_AGE )); then
    flag=0
fi

while IFS= read -r bad_user; do
    [[ -n "$bad_user" ]] && flag=0
done < <(awk -F: -v warn="$WARN_AGE" \
    '($2~/^\$.+\$/) {if($6 < warn) print $1}' /etc/shadow 2>/dev/null)

if (( flag )); then
    echo -e "${GREEN}SUCCESS${RESET}"
    exit 0
else
    echo -e "${RED}FAILED${RESET}"
    exit 1
fi
