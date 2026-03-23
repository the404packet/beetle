#!/usr/bin/env bash

NAME="/etc/shadow- backup file permissions"
SEVERITY="critical"

FILE="/etc/shadow-"

[ -e "$FILE" ] || exit 0
[ -f "$FILE" ] || exit 2

mode=$(stat -Lc '%a' "$FILE" 2>/dev/null) || exit 2
uid=$(stat -Lc '%u' "$FILE" 2>/dev/null) || exit 2
gid_name=$(stat -Lc '%G' "$FILE" 2>/dev/null) || exit 2

if [[ "$uid" -eq 0 && "$mode" -le 640 && ( "$gid_name" = "root" || "$gid_name" = "shadow" ) ]]; then
    echo -e "${GREEN}HARDENED${RESET}"
else
    echo -e "${RED}NOT HARDENED${RESET}"
fi

exit 0
