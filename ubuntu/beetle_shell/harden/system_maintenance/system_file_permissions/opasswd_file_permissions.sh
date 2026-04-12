#!/usr/bin/env bash

NAME="/etc/security/opasswd file permissions"
SEVERITY="basic"

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

FILE="/etc/security/opasswd"

# Create file if it does not exist
if [ ! -e "$FILE" ]; then
    install -m 600 -o root -g root /dev/null "$FILE" || { echo -e "${RED}HARDENED - FAILED${RESET}: could not create $FILE"; exit 1; }
fi

if chmod u-x,go-rwx "$FILE" && chown root:root "$FILE"; then
    echo -e "${GREEN}HARDENED - SUCCESS${RESET}"
else
    echo -e "${RED}HARDENED - FAILED${RESET}"
    exit 1
fi

exit 0