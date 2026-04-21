#!/usr/bin/env bash
NAME="ensure audit logs are not automatically deleted"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$LOGGING_RAM_STORE" ] && source "$LOGGING_RAM_STORE" || { echo -e "${RED}NOT HARDENED${RESET}"; exit 0; }

key="$AC_1_name"; valid="$AC_1_valid_values"

result=$(grep -Pi "^\s*${key}\s*=\s*(${valid})\b" "$AC_config_file" 2>/dev/null)
[ -n "$result" ] \
    && echo -e "${GREEN}HARDENED${RESET}" \
    || echo -e "${RED}NOT HARDENED${RESET}"
exit 0