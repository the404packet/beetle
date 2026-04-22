#!/usr/bin/env bash

NAME="ensure default user shell timeout is configured"
SEVERITY='basic'

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

[ -f "$SSH_RAM_STORE" ] && source "$SSH_RAM_STORE"

MAX_TMOUT="${UE_tmout_max:-900}"

output1=""
output2=""

BRC=""
[ -f /etc/bashrc ] && BRC="/etc/bashrc"

# Pattern: TMOUT=1..MAX_TMOUT AND readonly TMOUT AND export TMOUT — all in same file
for f in $BRC /etc/profile /etc/profile.d/*.sh; do
    [ -f "$f" ] || continue
    if grep -Pq "^\s*([^#]+\s+)?TMOUT=($MAX_TMOUT|[1-8][0-9][0-9]|[1-9][0-9]|[1-9])\b" "$f" \
    && grep -Pq '^\s*([^#]+;\s*)?readonly\s+TMOUT(\s+|\s*;|\s*$|=[0-9]+)\b' "$f" \
    && grep -Pq '^\s*([^#]+;\s*)?export\s+TMOUT(\s+|\s*;|\s*$|=[0-9]+)\b' "$f"; then
        output1="$f"
    fi
done

# Check for excessively large or zero TMOUT
for f in /etc/profile /etc/profile.d/*.sh $BRC; do
    [ -f "$f" ] || continue
    if grep -Pq "^\s*([^#]+\s+)?TMOUT=(9[0-9][1-9]|9[1-9][0-9]|0+|[1-9]\d{3,})\b" "$f"; then
        output2="$f"
    fi
done

if [[ -n "$output1" && -z "$output2" ]]; then
    echo -e "${GREEN}HARDENED${RESET}"
else
    echo -e "${RED}NOT HARDENED${RESET}"
fi

exit 0
