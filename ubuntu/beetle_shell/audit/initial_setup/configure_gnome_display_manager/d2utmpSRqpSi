#!/usr/bin/env bash
NAME="ensure GDM login banner is configured"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$INITIAL_SETUP_RAM_STORE" ] && source "$INITIAL_SETUP_RAM_STORE" || { echo -e "${RED}NOT HARDENED${RESET}"; exit 0; }
gdm_installed || { echo -e "${GREEN}HARDENED${RESET}"; exit 0; }

enabled=$(grep -Phs '^\s*banner-message-enable\s*=\s*true' \
    "$GD_banner_file" "$GD_login_screen_file" 2>/dev/null | head -1)
text=$(grep -Phs '^\s*banner-message-text\s*=' \
    "$GD_banner_file" "$GD_login_screen_file" 2>/dev/null | head -1)

[ -n "$enabled" ] && [ -n "$text" ] \
    && echo -e "${GREEN}HARDENED${RESET}" \
    || echo -e "${RED}NOT HARDENED${RESET}"
exit 0