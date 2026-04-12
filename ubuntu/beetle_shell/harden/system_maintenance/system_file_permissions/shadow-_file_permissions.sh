#!/usr/bin/env bash

NAME="/etc/shadow- backup file permissions"
SEVERITY="critical"

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

FILE="/etc/shadow-"

[ -e "$FILE" ] || exit 0
[ -f "$FILE" ] || exit 2

# Set group to shadow if it exists, otherwise fall back to root
if getent group shadow &>/dev/null; then
    chown_cmd="chown root:shadow"
else
    chown_cmd="chown root:root"
fi

if chmod u-x,g-wx,o-rwx "$FILE" && $chown_cmd "$FILE"; then
    echo -e "${GREEN}HARDENED - SUCCESS${RESET}"
else
    echo -e "${RED}HARDENED - FAILED${RESET}"
    exit 1
fi

exit 0