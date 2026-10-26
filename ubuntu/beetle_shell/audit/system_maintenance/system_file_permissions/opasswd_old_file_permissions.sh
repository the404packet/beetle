#!/usr/bin/env bash

NAME="/etc/security/opasswd.old file permissions"

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

FILE="/etc/security/opasswd.old"

[ -f "$PERM_RAM_STORE" ] && source "$PERM_RAM_STORE"

EXPECTED_MODE=$(get_perm "$FILE" mode)
EXPECTED_OWNER=$(get_perm "$FILE" owner)
EXPECTED_GROUP=$(get_perm "$FILE" group)

# File must exist (harden will create it)
if [ ! -e "$FILE" ]; then
    echo -e "${RED}NOT HARDENED${RESET}"
    exit 0
fi

[ -f "$FILE" ] || { echo -e "${RED}NOT HARDENED${RESET}"; exit 0; }

mode=$(stat -Lc '%a' "$FILE" 2>/dev/null)
owner=$(stat -Lc '%U' "$FILE" 2>/dev/null)
group=$(stat -Lc '%G' "$FILE" 2>/dev/null)

if [[ -n "$mode" && "$owner" == "$EXPECTED_OWNER" && "$group" == "$EXPECTED_GROUP" && "$mode" -le "$EXPECTED_MODE" ]]; then
    echo -e "${GREEN}HARDENED${RESET}"
else
    echo -e "${RED}NOT HARDENED${RESET}"
fi

exit 0