#!/usr/bin/env bash
NAME="ensure filesystem integrity is regularly checked"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$LOGGING_RAM_STORE" ] && source "$LOGGING_RAM_STORE" || { echo -e "${RED}NOT HARDENED${RESET}"; exit 0; }

require_present pkg aide-common

[ -z "$AI_timer" ]   && { echo -e "${RED}NOT HARDENED${RESET}"; exit 0; }
[ -z "$AI_service" ] && { echo -e "${RED}NOT HARDENED${RESET}"; exit 0; }

timer_enabled=$(systemctl is-enabled "$AI_timer"   2>/dev/null)
svc_status=$(systemctl  is-enabled "$AI_service" 2>/dev/null)
timer_active=$(systemctl is-active  "$AI_timer"   2>/dev/null)

[ "$timer_enabled" = "enabled" ] \
    && [[ "$svc_status" =~ ^(static|enabled)$ ]] \
    && [ "$timer_active" = "active" ] \
    && echo -e "${GREEN}HARDENED${RESET}" \
    || echo -e "${RED}NOT HARDENED${RESET}"
exit 0
