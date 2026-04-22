#!/usr/bin/env bash
NAME="ensure GDM disable-user-list option is enabled"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$INITIAL_SETUP_RAM_STORE" ] && source "$INITIAL_SETUP_RAM_STORE" || { echo -e "${RED}NOT HARDENED${RESET}"; exit 0; }
gdm_installed || { echo -e "${GREEN}HARDENED${RESET}"; exit 0; }

grep -Prhsq '^\s*disable-user-list\s*=\s*true' \
    "$GD_db_dir" "$GD_gdm_db_dir" 2>/dev/null \
    && echo -e "${GREEN}HARDENED${RESET}" \
    || echo -e "${RED}NOT HARDENED${RESET}"
exit 0