#!/usr/bin/env bash

NAME="/etc/security/opasswd file permissions"
SEVERITY="basic"

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

FILE="/etc/security/opasswd"

[ -f "$PERM_RAM_STORE" ] && source "$PERM_RAM_STORE"

EXPECTED_MODE=$(get_perm "$FILE" mode)
EXPECTED_OWNER=$(get_perm "$FILE" owner)
EXPECTED_GROUP=$(get_perm "$FILE" group)

# Create file if it does not exist
if [ ! -e "$FILE" ]; then
    install -m "$EXPECTED_MODE" -o "$EXPECTED_OWNER" -g "$EXPECTED_GROUP" /dev/null "$FILE" || {
        echo -e "${RED}FAILED${RESET}: could not create $FILE"
        exit 1
    }
fi

if chmod "$EXPECTED_MODE" "$FILE" && chown "${EXPECTED_OWNER}:${EXPECTED_GROUP}" "$FILE"; then
    echo -e "${GREEN}SUCCESS${RESET}"
else
    echo -e "${RED}FAILED${RESET}"
    exit 1
fi

exit 0