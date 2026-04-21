#!/usr/bin/env bash
NAME="ensure rsyslog is installed"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$DPKG_RAM_STORE" ]    && source "$DPKG_RAM_STORE"
[ -f "$LOGGING_RAM_STORE" ] && source "$LOGGING_RAM_STORE" || { echo -e "${RED}FAILED${RESET}"; exit 1; }

if ! is_package_installed "$RS_package"; then
    apt-get install -y "$RS_package" 2>/dev/null \
        || { echo -e "${RED}FAILED${RESET}"; exit 1; }
fi

is_package_installed "$RS_package" \
    && echo -e "${GREEN}SUCCESS${RESET}" \
    || { echo -e "${RED}FAILED${RESET}"; exit 1; }
exit 0