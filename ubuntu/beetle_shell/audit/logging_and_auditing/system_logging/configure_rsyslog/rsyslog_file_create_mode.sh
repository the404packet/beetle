#!/usr/bin/env bash
NAME="ensure rsyslog log file creation mode is configured"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$LOGGING_RAM_STORE" ] && source "$LOGGING_RAM_STORE" || { echo -e "${RED}NOT HARDENED${RESET}"; exit 0; }

perm_mask="0137"
found=$(grep -rPs '^\s*\$FileCreateMode\s+\d+' \
        "$RS_config_file" "$RS_config_dir"/ 2>/dev/null | tail -1)

if [ -z "$found" ]; then
    echo -e "${RED}NOT HARDENED${RESET}"; exit 0
fi

mode=$(awk '{print $2}' <<< "$found" | tr -d ' ')
[ $(( 8#$mode & 8#$perm_mask )) -gt 0 ] \
    && echo -e "${RED}NOT HARDENED${RESET}" \
    || echo -e "${GREEN}HARDENED${RESET}"
exit 0