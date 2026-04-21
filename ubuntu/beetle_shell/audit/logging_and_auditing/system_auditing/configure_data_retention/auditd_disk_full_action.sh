#!/usr/bin/env bash
NAME="ensure system is disabled when audit logs are full"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$LOGGING_RAM_STORE" ] && source "$LOGGING_RAM_STORE" || { echo -e "${RED}NOT HARDENED${RESET}"; exit 0; }

key1="$AC_2_name"; valid1="$AC_2_valid_values"
key2="$AC_3_name"; valid2="$AC_3_valid_values"

r1=$(grep -Pi "^\s*${key1}\s*=\s*(${valid1})\b" "$AC_config_file" 2>/dev/null)
r2=$(grep -Pi "^\s*${key2}\s*=\s*(${valid2})\b" "$AC_config_file" 2>/dev/null)

[ -n "$r1" ] && [ -n "$r2" ] \
    && echo -e "${GREEN}HARDENED${RESET}" \
    || echo -e "${RED}NOT HARDENED${RESET}"
exit 0