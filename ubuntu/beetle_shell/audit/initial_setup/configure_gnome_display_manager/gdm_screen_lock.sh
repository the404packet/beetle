#!/usr/bin/env bash
NAME="ensure GDM screen locks when the user is idle"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$INITIAL_SETUP_RAM_STORE" ] && source "$INITIAL_SETUP_RAM_STORE" || { echo -e "${RED}NOT HARDENED${RESET}"; exit 0; }
gdm_installed || { echo -e "${GREEN}HARDENED${RESET}"; exit 0; }

idle=$(grep -Prhs '^\s*idle-delay\s*=\s*uint32\s+\d+' "$GD_db_dir" 2>/dev/null \
    | awk '{print $NF}' | tail -1)
lock=$(grep -Prhs '^\s*lock-delay\s*=\s*uint32\s+\d+' "$GD_db_dir" 2>/dev/null \
    | awk '{print $NF}' | tail -1)

[ -n "$idle" ] && [ "$idle" -le "$GD_idle_delay" ] && [ "$idle" -gt 0 ] \
    && [ -n "$lock" ] && [ "$lock" -le "$GD_lock_delay" ] \
    && echo -e "${GREEN}HARDENED${RESET}" \
    || echo -e "${RED}NOT HARDENED${RESET}"
exit 0