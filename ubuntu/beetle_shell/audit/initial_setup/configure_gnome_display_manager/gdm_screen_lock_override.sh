#!/usr/bin/env bash
NAME="ensure GDM screen locks cannot be overridden"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$INITIAL_SETUP_RAM_STORE" ] && source "$INITIAL_SETUP_RAM_STORE" || { echo -e "${RED}NOT HARDENED${RESET}"; exit 0; }
gdm_installed || { echo -e "${GREEN}HARDENED${RESET}"; exit 0; }

fail=0
for key in "/org/gnome/desktop/session/idle-delay" "/org/gnome/desktop/screensaver/lock-delay"; do
    grep -Psrilq "^\s*${key}\b" "$GD_locks_dir"/ 2>/dev/null || { fail=1; break; }
done

[ "$fail" -eq 0 ] \
    && echo -e "${GREEN}HARDENED${RESET}" \
    || echo -e "${RED}NOT HARDENED${RESET}"
exit 0