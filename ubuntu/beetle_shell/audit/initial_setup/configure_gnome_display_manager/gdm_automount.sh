#!/usr/bin/env bash
NAME="ensure GDM automatic mounting of removable media is disabled"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$INITIAL_SETUP_RAM_STORE" ] && source "$INITIAL_SETUP_RAM_STORE" || { echo -e "${RED}NOT HARDENED${RESET}"; exit 0; }
gdm_installed || { echo -e "${GREEN}HARDENED${RESET}"; exit 0; }

am=$(grep -Prhsq '^\s*automount\s*=\s*false' "$GD_db_dir" 2>/dev/null && echo ok)
ao=$(grep -Prhsq '^\s*automount-open\s*=\s*false' "$GD_db_dir" 2>/dev/null && echo ok)

[ "$am" = "ok" ] && [ "$ao" = "ok" ] \
    && echo -e "${GREEN}HARDENED${RESET}" \
    || echo -e "${RED}NOT HARDENED${RESET}"
exit 0