#!/usr/bin/env bash

NAME="verify shadow group has no members or primary users"
SEVERITY="basic"

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

GROUP_FILE="/etc/group"
PASSWD_FILE="/etc/passwd"

[ -f "$GROUP_FILE" ] || exit 2
[ -f "$PASSWD_FILE" ] || exit 2

shadow_gid=$(getent group shadow | awk -F: '{print $3}')

[ -z "$shadow_gid" ] && {
    echo -e "${GREEN}SUCCESS${RESET}"
    exit 0
}

shadow_members=$(awk -F: '($1=="shadow" && $NF!="") {print $NF}' "$GROUP_FILE")
primary_users=$(awk -F: '($4 == '"$shadow_gid"') {print $1}' "$PASSWD_FILE")

if [[ -z "$shadow_members" && -z "$primary_users" ]]; then
    echo -e "${GREEN}SUCCESS${RESET}"
    exit 0
fi

FAILED=0

# Remove all members from shadow group
if [[ -n "$shadow_members" ]]; then
    sed -ri 's/(^shadow:[^:]*:[^:]*:)([^:]+$)/\1/' "$GROUP_FILE" 2>/dev/null || FAILED=1
fi

# Move primary users to their own group
if [[ -n "$primary_users" ]]; then
    while IFS= read -r user; do
        if ! getent group "$user" &>/dev/null; then
            groupadd "$user" 2>/dev/null || { FAILED=1; continue; }
        fi
        usermod -g "$user" "$user" 2>/dev/null || FAILED=1
    done <<< "$primary_users"
fi

if [[ "$FAILED" -eq 0 ]]; then
    echo -e "${GREEN}SUCCESS${RESET}"
else
    echo -e "${RED}FAILED${RESET}"
    exit 1
fi

exit 0