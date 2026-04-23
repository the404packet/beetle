#!/usr/bin/env bash

NAME="/etc/shadow file permissions"
SEVERITY="critical"

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

FILE="/etc/shadow"

[ -f "$PERM_RAM_STORE" ] && source "$PERM_RAM_STORE"

EXPECTED_MODE=$(get_perm "$FILE" mode)
EXPECTED_OWNER=$(get_perm "$FILE" owner)
EXPECTED_GROUP=$(get_perm "$FILE" group)

[ -f "$FILE" ] || exit 2
    
mode=$(stat -Lc '%a' "$FILE" 2>/dev/null) || exit 2
owner=$(stat -Lc '%U' "$FILE" 2>/dev/null) || exit 2
group=$(stat -Lc '%G' "$FILE" 2>/dev/null) || exit 2

if [[ "$owner" == "$EXPECTED_OWNER" && "$mode" -le "$EXPECTED_MODE" && ( "$group" == "$EXPECTED_GROUP" || "$group" == "root" ) ]]; then
    echo -e "${GREEN}HARDENED${RESET}"
else
    echo -e "${RED}NOT HARDENED${RESET}"
fi

exit 0