#!/usr/bin/env bash
NAME="ensure filesystem integrity is regularly checked"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$LOGGING_RAM_STORE" ] && source "$LOGGING_RAM_STORE" || { echo -e "${RED}NOT HARDENED${RESET}"; exit 0; }

timer_enabled=$(systemctl list-unit-files 2>/dev/null \
    | awk -v t="$AI_timer" '$1==t{print $2}')
svc_status=$(systemctl list-unit-files 2>/dev/null \
    | awk -v s="$AI_service" '$1==s{print $2}')
timer_active=$(systemctl is-active "$AI_timer" 2>/dev/null)

[ "$timer_enabled" = "enabled" ] \
    && [[ "$svc_status" =~ ^(static|enabled)$ ]] \
    && [ "$timer_active" = "active" ] \
    && echo -e "${GREEN}HARDENED${RESET}" \
    || echo -e "${RED}NOT HARDENED${RESET}"
exit 0