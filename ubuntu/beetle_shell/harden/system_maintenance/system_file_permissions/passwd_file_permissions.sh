#!/usr/bin/env bash

NAME="/etc/passwd user database permission"
SEVERITY="basic"

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

FILE="/etc/passwd"

chmod u-x,go-wx "$FILE" || { echo -e "${RED}HARDENING FAILED${RESET}: chmod on $FILE"; exit 1; }
chown root:root "$FILE" || { echo -e "${RED}HARDENING FAILED${RESET}: chown on $FILE"; exit 1; }

echo -e "${GREEN}HARDENED SUCCESS${RESET}"
exit 0