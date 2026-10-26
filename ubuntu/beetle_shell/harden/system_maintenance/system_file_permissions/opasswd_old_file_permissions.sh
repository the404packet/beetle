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

# Sanity: JSON must define expected values
if [ -z "$EXPECTED_MODE" ] || [ -z "$EXPECTED_OWNER" ] || [ -z "$EXPECTED_GROUP" ]; then
    echo -e "${RED}FAILED${RESET}: expected values not defined in JSON"
    exit 1
fi

# Create file if it does not exist
if [ ! -e "$FILE" ]; then
    install -m "$EXPECTED_MODE" -o "$EXPECTED_OWNER" -g "$EXPECTED_GROUP" /dev/null "$FILE" 2>/dev/null || true
fi

# Apply expected permissions
chmod "$EXPECTED_MODE" "$FILE"          2>/dev/null || true
chown "${EXPECTED_OWNER}:${EXPECTED_GROUP}" "$FILE" 2>/dev/null || true

# Verify
mode=$(stat -Lc '%a' "$FILE" 2>/dev/null)
owner=$(stat -Lc '%U' "$FILE" 2>/dev/null)
group=$(stat -Lc '%G' "$FILE" 2>/dev/null)

if [[ -n "$mode" && "$owner" == "$EXPECTED_OWNER" && "$group" == "$EXPECTED_GROUP" && "$mode" -le "$EXPECTED_MODE" ]]; then
    echo -e "${GREEN}SUCCESS${RESET}"
    exit 0
fi

echo -e "${RED}FAILED${RESET}"
exit 1