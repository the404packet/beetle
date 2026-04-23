#!/usr/bin/env bash

NAME="ensure inactive password lock is configured"
SEVERITY='basic'

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

[ -f "$SSH_RAM_STORE" ] && source "$SSH_RAM_STORE"

MAX_INACTIVE="${LD_inactive_max:-45}"

# Set the system-wide default for new users
useradd -D -f "$MAX_INACTIVE"

# Apply to all existing users with a password whose INACTIVE is out of range
awk -F: -v max="$MAX_INACTIVE" \
    '($2~/^\$.+\$/) {if($7 > max || $7 < 0) print $1}' \
    /etc/shadow 2>/dev/null | while IFS= read -r user; do
    chage --inactive "$MAX_INACTIVE" "$user"
done

# Validate
flag=1
inactive_val=$(useradd -D 2>/dev/null | grep -i INACTIVE | cut -d= -f2 | xargs)
if [[ -z "$inactive_val" ]] || (( inactive_val < 0 || inactive_val > MAX_INACTIVE )); then
    flag=0
fi

while IFS= read -r bad_user; do
    [[ -n "$bad_user" ]] && flag=0
done < <(awk -F: -v max="$MAX_INACTIVE" \
    '($2~/^\$.+\$/) {if($7 > max || $7 < 0) print $1}' /etc/shadow 2>/dev/null)

if (( flag )); then
    echo -e "${GREEN}SUCCESS${RESET}"
    exit 0
else
    echo -e "${RED}FAILED${RESET}"
    exit 1
fi
