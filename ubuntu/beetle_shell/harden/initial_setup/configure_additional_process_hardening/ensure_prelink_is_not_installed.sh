#!/usr/bin/env bash
NAME='ensure prelink is not installed'
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$DPKG_RAM_STORE" ] && source "$DPKG_RAM_STORE"

if is_package_installed "prelink"; then
    prelink -ua 2>/dev/null
    apt-get purge -y prelink 2>/dev/null
    unset_package "prelink"
fi

is_package_installed "prelink" \
    && { echo -e "${RED}FAILED${RESET}"; exit 1; } \
    || { echo -e "${GREEN}SUCCESS${RESET}"; exit 0; }