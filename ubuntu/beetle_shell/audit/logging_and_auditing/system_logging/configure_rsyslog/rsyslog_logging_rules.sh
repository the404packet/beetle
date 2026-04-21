#!/usr/bin/env bash
NAME="ensure rsyslog logging is configured"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$LOGGING_RAM_STORE" ] && source "$LOGGING_RAM_STORE" || { echo -e "${RED}NOT HARDENED${RESET}"; exit 0; }

fail=0
count="$RS_rules_count"
for ((i=0; i<count; i++)); do
    dest_var="RS_${i}_dest"; dest="${!dest_var}"
    dest_clean="${dest#-}"
    grep -rqPs "^\s*[^#].*${dest_clean//\//\\/}" \
        "$RS_config_file" "$RS_config_dir"/ 2>/dev/null || fail=1
done

[ "$fail" -eq 0 ] \
    && echo -e "${GREEN}HARDENED${RESET}" \
    || echo -e "${RED}NOT HARDENED${RESET}"
exit 0