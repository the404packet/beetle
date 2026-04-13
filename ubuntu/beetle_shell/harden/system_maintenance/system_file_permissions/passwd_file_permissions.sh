#!/usr/bin/env bash

NAME="/etc/passwd user database permission"
SEVERITY="basic"

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

FILE="/etc/passwd"

[ -f "$PERM_RAM_STORE" ] && source "$PERM_RAM_STORE"

EXPECTED_MODE=$(get_perm "$FILE" mode)
EXPECTED_OWNER=$(get_perm "$FILE" owner)
EXPECTED_GROUP=$(get_perm "$FILE" group)

[ -f "$FILE" ] || exit 2

if chmod "$EXPECTED_MODE" "$FILE" && chown "${EXPECTED_OWNER}:${EXPECTED_GROUP}" "$FILE"; then
    echo -e "${GREEN}SUCCESS${RESET}"
else
    echo -e "${RED}FAILED${RESET}"
    exit 1
fi

exit 0