#!/usr/bin/env bash
NAME="ensure auditd service is enabled and active"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$LOGGING_RAM_STORE" ] && source "$LOGGING_RAM_STORE" || { echo -e "${RED}NOT HARDENED${RESET}"; exit 0; }

enabled=$(systemctl is-enabled "$AD_service" 2>/dev/null)
active=$(systemctl  is-active  "$AD_service" 2>/dev/null)

[ "$enabled" = "enabled" ] && [ "$active" = "active" ] \
    && echo -e "${GREEN}HARDENED${RESET}" \
    || echo -e "${RED}NOT HARDENED${RESET}"
exit 0