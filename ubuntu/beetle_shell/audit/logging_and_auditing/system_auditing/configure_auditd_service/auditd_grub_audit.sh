#!/usr/bin/env bash
NAME="ensure auditing for processes prior to auditd is enabled"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$LOGGING_RAM_STORE" ] && source "$LOGGING_RAM_STORE" || { echo -e "${RED}NOT HARDENED${RESET}"; exit 0; }

result=$(find /boot -type f -name 'grub.cfg' \
         -exec grep -Ph -- '^\h*linux' {} + 2>/dev/null \
         | grep -v 'audit=1')

[ -z "$result" ] \
    && echo -e "${GREEN}HARDENED${RESET}" \
    || echo -e "${RED}NOT HARDENED${RESET}"
exit 0