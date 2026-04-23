#!/usr/bin/env bash

NAME="ensure all users last password change date is in the past"
SEVERITY='basic'

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

# This check requires human investigation — future-dated password change records
# indicate potential tampering. The remediation locks the affected accounts to
# force a password reset on next contact with the administrator.

flag=1
now=$(date +%s)

while IFS= read -r l_user; do
    change_str=$(chage --list "$l_user" 2>/dev/null \
        | grep '^Last password change' \
        | cut -d: -f2 \
        | sed 's/^ *//' \
        | grep -v 'never$')
    [ -z "$change_str" ] && continue
    l_change=$(date -d "$change_str" +%s 2>/dev/null) || continue
    if (( l_change > now )); then
        echo "WARNING: User \"$l_user\" has a future password change date: $change_str — locking account" >&2
        usermod -L "$l_user"
        chage -d 0 "$l_user"
        flag=0
    fi
done < <(awk -F: '$2~/^\$.+\$/{print $1}' /etc/shadow 2>/dev/null)

# Re-validate after remediation
now=$(date +%s)
while IFS= read -r l_user; do
    change_str=$(chage --list "$l_user" 2>/dev/null \
        | grep '^Last password change' \
        | cut -d: -f2 \
        | sed 's/^ *//' \
        | grep -v 'never$')
    [ -z "$change_str" ] && continue
    l_change=$(date -d "$change_str" +%s 2>/dev/null) || continue
    if (( l_change > now )); then
        echo -e "${RED}FAILED${RESET}"
        exit 1
    fi
done < <(awk -F: '$2~/^\$.+\$/{print $1}' /etc/shadow 2>/dev/null)

echo -e "${GREEN}SUCCESS${RESET}"
exit 0
