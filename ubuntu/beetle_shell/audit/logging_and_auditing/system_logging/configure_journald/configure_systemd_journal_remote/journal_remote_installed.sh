#!/usr/bin/env bash
NAME="ensure systemd-journal-remote is installed"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$DPKG_RAM_STORE" ]    && source "$DPKG_RAM_STORE"
[ -f "$LOGGING_RAM_STORE" ] && source "$LOGGING_RAM_STORE" || { echo -e "${RED}NOT HARDENED${RESET}"; exit 0; }

is_package_installed "$JR_package" \
    && echo -e "${GREEN}HARDENED${RESET}" \
    || { echo -e "${RED}NOT HARDENED${RESET}"; }
exit 0