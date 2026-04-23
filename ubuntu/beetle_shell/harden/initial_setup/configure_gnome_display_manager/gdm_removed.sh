#!/usr/bin/env bash
NAME="ensure GDM is removed"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$DPKG_RAM_STORE" ]          && source "$DPKG_RAM_STORE"
[ -f "$INITIAL_SETUP_RAM_STORE" ] && source "$INITIAL_SETUP_RAM_STORE" || { echo -e "${RED}FAILED${RESET}"; exit 1; }

if is_package_installed "$GD_package"; then
    apt-get purge -y "$GD_package" 2>/dev/null
    apt-get autoremove -y 2>/dev/null
fi

is_package_installed "$GD_package" \
    && { echo -e "${RED}FAILED${RESET}"; exit 1; } \
    || echo -e "${GREEN}SUCCESS${RESET}"
exit 0