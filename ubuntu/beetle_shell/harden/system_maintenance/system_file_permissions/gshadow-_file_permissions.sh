#!/usr/bin/env bash

NAME="/etc/gshadow- backup file permissions"
SEVERITY="basic"

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

FILE="/etc/gshadow-"

[ -f "$PERM_RAM_STORE" ] && source "$PERM_RAM_STORE"

EXPECTED_MODE=$(get_perm "$FILE" mode)
EXPECTED_OWNER=$(get_perm "$FILE" owner)
EXPECTED_GROUP=$(get_perm "$FILE" group)

[ -e "$FILE" ] || exit 0
[ -f "$FILE" ] || exit 2

# Fall back to root if shadow group does not exist
if ! getent group "$EXPECTED_GROUP" &>/dev/null; then
    EXPECTED_GROUP="root"
fi

if chmod "$EXPECTED_MODE" "$FILE" && chown "${EXPECTED_OWNER}:${EXPECTED_GROUP}" "$FILE"; then
    echo -e "${GREEN}SUCCESS${RESET}"
else
    echo -e "${RED}FAILED${RESET}"
    exit 1
fi

exit 0