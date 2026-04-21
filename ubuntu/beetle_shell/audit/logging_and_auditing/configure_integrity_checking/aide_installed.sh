#!/usr/bin/env bash
NAME="ensure AIDE is installed"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$DPKG_RAM_STORE" ]    && source "$DPKG_RAM_STORE"
[ -f "$LOGGING_RAM_STORE" ] && source "$LOGGING_RAM_STORE" || { echo -e "${RED}NOT HARDENED${RESET}"; exit 0; }

count="$AI_pkg_count"
for ((i=0; i<count; i++)); do
    n_var="AI_pkg_${i}_name"; pkg="${!n_var}"
    is_package_installed "$pkg" || { echo -e "${RED}NOT HARDENED${RESET}"; exit 0; }
done

echo -e "${GREEN}HARDENED${RESET}"; exit 0