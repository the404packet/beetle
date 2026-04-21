#!/usr/bin/env bash
NAME="ensure audit logs are not automatically deleted"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$LOGGING_RAM_STORE" ] && source "$LOGGING_RAM_STORE" || { echo -e "${RED}FAILED${RESET}"; exit 1; }

key="$AC_1_name"; val="$AC_1_value"; valid="$AC_1_valid_values"

if grep -Pq "^\s*${key}\s*=" "$AC_config_file" 2>/dev/null; then
    sed -i "s|^\s*${key}\s*=.*|${key} = ${val}|" "$AC_config_file"
else
    echo "${key} = ${val}" >> "$AC_config_file"
fi

result=$(grep -Pi "^\s*${key}\s*=\s*(${valid})\b" "$AC_config_file" 2>/dev/null)
[ -n "$result" ] \
    && echo -e "${GREEN}SUCCESS${RESET}" \
    || { echo -e "${RED}FAILED${RESET}"; exit 1; }
exit 0