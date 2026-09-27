#!/usr/bin/env bash
NAME="ensure rsyslog log file creation mode is configured"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$LOGGING_RAM_STORE" ] && source "$LOGGING_RAM_STORE" || { echo -e "${RED}NOT HARDENED${RESET}"; exit 0; }

[ "${LJ_preferred_logging_system:-journald}" != "rsyslog" ] && { echo -e "${GREEN}HARDENED${RESET}"; exit 0; }

require_present pkg rsyslog

perm_mask="0137"

drop_file="${RS_config_dir}/${RS_drop_file}"
if [ -f "$drop_file" ]; then
    found=$(grep -Ps '^\s*\$FileCreateMode\s+\d+' "$drop_file" 2>/dev/null | tail -1)
else
    found=$(grep -rPs '^\s*\$FileCreateMode\s+\d+' \
            "$RS_config_file" "$RS_config_dir"/ 2>/dev/null | tail -1)
fi

if [ -z "$found" ]; then
    echo -e "${RED}NOT HARDENED${RESET}"; exit 0
fi

mode=$(awk '{print $2}' <<< "$found" | tr -d ' ')
[ $(( 8#$mode & 8#$perm_mask )) -gt 0 ] \
    && echo -e "${RED}NOT HARDENED${RESET}" \
    || echo -e "${GREEN}HARDENED${RESET}"
exit 0
