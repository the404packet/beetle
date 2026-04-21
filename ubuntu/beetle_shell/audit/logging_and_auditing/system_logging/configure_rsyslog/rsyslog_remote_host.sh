#!/usr/bin/env bash
NAME="ensure rsyslog is configured to send logs to a remote log host"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$LOGGING_RAM_STORE" ] && source "$LOGGING_RAM_STORE" || { echo -e "${RED}NOT HARDENED${RESET}"; exit 0; }

# check both basic (@@) and advanced (action omfwd target=) formats
found_basic=$(grep -rHs '^\*\.\*.*@@' \
              "$RS_config_file" "$RS_config_dir"/ 2>/dev/null | head -1)
found_adv=$(grep -rPHsi '^\s*([^#]+\s+)?action\(([^#]+\s+)?\btarget=' \
            "$RS_config_file" "$RS_config_dir"/ 2>/dev/null | head -1)

[ -n "$found_basic" ] || [ -n "$found_adv" ] \
    && echo -e "${GREEN}HARDENED${RESET}" \
    || echo -e "${RED}NOT HARDENED${RESET}"
exit 0