#!/usr/bin/env bash

NAME="/etc/security/opasswd.old file permissions"

FILE="/etc/security/opasswd.old"

[ -e "$FILE" ] || exit 1
[ -f "$FILE" ] || exit 2

mode=$(stat -Lc '%a' "$FILE" 2>/dev/null) || exit 2
uid=$(stat -Lc '%u' "$FILE" 2>/dev/null) || exit 2
gid=$(stat -Lc '%g' "$FILE" 2>/dev/null) || exit 2

if [[ "$uid" -eq 0 && "$gid" -eq 0 && "$mode" -le 600 ]]; then
    echo -e "${GREEN}HARDENED${RESET}"
else
    echo -e "${RED}NOT HARDENED${RESET}"
fi

exit 0
