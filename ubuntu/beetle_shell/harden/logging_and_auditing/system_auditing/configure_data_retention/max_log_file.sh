#!/usr/bin/env bash
NAME="ensure audit log storage size is configured"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$LOGGING_RAM_STORE" ] && source "$LOGGING_RAM_STORE" || { echo -e "${RED}FAILED${RESET}"; exit 1; }

key="$AC_0_name"; val="$AC_0_value"

if grep -Pq "^\s*${key}\s*=" "$AC_config_file" 2>/dev/null; then
    sed -i "s|^\s*${key}\s*=.*|${key} = ${val}|" "$AC_config_file"
else
    echo "${key} = ${val}" >> "$AC_config_file"
fi

result=$(grep -Po "^\s*${key}\s*=\s*\d+\b" "$AC_config_file" 2>/dev/null)
[ -n "$result" ] \
    && echo -e "${GREEN}SUCCESS${RESET}" \
    || { echo -e "${RED}FAILED${RESET}"; exit 1; }
exit 0