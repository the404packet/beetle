#!/usr/bin/env bash
NAME="ensure audit log storage size is configured"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$LOGGING_RAM_STORE" ] && source "$LOGGING_RAM_STORE" || { echo -e "${RED}NOT HARDENED${RESET}"; exit 0; }

result=$(grep -Po '^\s*max_log_file\s*=\s*\d+\b' "$AC_config_file" 2>/dev/null)

[ -n "$result" ] \
    && echo -e "${GREEN}HARDENED${RESET}" \
    || echo -e "${RED}NOT HARDENED${RESET}"
exit 0