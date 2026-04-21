#!/usr/bin/env bash
NAME="ensure filesystem integrity is regularly checked"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$LOGGING_RAM_STORE" ] && source "$LOGGING_RAM_STORE" || { echo -e "${RED}FAILED${RESET}"; exit 1; }

systemctl unmask "$AI_timer" "$AI_service" 2>/dev/null
systemctl --now enable "$AI_timer" 2>/dev/null \
    || { echo -e "${RED}FAILED${RESET}"; exit 1; }

timer_active=$(systemctl is-active "$AI_timer" 2>/dev/null)
[ "$timer_active" = "active" ] \
    && echo -e "${GREEN}SUCCESS${RESET}" \
    || { echo -e "${RED}FAILED${RESET}"; exit 1; }
exit 0