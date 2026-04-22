#!/usr/bin/env bash
NAME='ensure prelink is not installed'
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$DPKG_RAM_STORE" ] && source "$DPKG_RAM_STORE"

is_package_installed "prelink" \
    && echo -e "${RED}NOT HARDENED${RESET}" \
    || echo -e "${GREEN}HARDENED${RESET}"
exit 0