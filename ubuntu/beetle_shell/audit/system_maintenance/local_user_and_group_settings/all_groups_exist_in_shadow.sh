#!/usr/bin/env bash

NAME="all passwd GIDs exist in group"

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

PASSWD_FILE="/etc/passwd"
GROUP_FILE="/etc/group"

[ -f "$PASSWD_FILE" ] || exit 2
[ -f "$GROUP_FILE" ] || exit 2

# For each user's primary GID, check whether that GID exists in /etc/group.
missing_users=$(
    while IFS=: read -r user _ uid gid _; do
        [ -z "$gid" ] && continue
        if ! awk -F: -v g="$gid" '$3 == g {found=1; exit} END {exit !found}' "$GROUP_FILE"; then
            echo " - User: \"$user\" has GID: \"$gid\" which does not exist in /etc/group"
        fi
    done < "$PASSWD_FILE"
)

if [[ -z "$missing_users" ]]; then
    echo -e "${GREEN}HARDENED${RESET}"
    exit 0
fi

echo -e "${RED}NOT HARDENED${RESET}"
echo "$missing_users"
exit 0