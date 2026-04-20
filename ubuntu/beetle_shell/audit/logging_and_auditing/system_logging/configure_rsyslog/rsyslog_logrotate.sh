#!/usr/bin/env bash
NAME="ensure logrotate is configured"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$LOGGING_RAM_STORE" ] && source "$LOGGING_RAM_STORE" || { echo -e "${RED}NOT HARDENED${RESET}"; exit 0; }

found=$(grep -rPs '^\s*(daily|weekly|monthly|rotate\s+\d+|maxage\s+\d+)' \
        "$RS_logrotate_config" "$RS_logrotate_dir"/ 2>/dev/null | head -1)

[ -n "$found" ] \
    && echo -e "${GREEN}HARDENED${RESET}" \
    || echo -e "${RED}NOT HARDENED${RESET}"
exit 0