#!/usr/bin/env bash
NAME="ensure systemd-journal-remote is installed"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$DPKG_RAM_STORE" ]    && source "$DPKG_RAM_STORE"
[ -f "$LOGGING_RAM_STORE" ] && source "$LOGGING_RAM_STORE" || { echo -e "${RED}FAILED${RESET}"; exit 1; }

export DEBIAN_FRONTEND=noninteractive

if ! is_package_installed "$JR_package"; then
    apt-get install -y -q "$JR_package" </dev/null >/dev/null 2>&1 || true
fi

if live_package_installed "$JR_package"; then
    echo -e "${GREEN}SUCCESS${RESET}"
    exit 0
fi

echo -e "${RED}FAILED${RESET}"
exit 1
