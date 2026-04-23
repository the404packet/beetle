#!/usr/bin/env bash
NAME="ensure AppArmor is installed"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$DPKG_RAM_STORE" ]          && source "$DPKG_RAM_STORE"
[ -f "$INITIAL_SETUP_RAM_STORE" ] && source "$INITIAL_SETUP_RAM_STORE" || { echo -e "${RED}NOT HARDENED${RESET}"; exit 0; }

count="$AA_pkg_count"
for ((i=0; i<count; i++)); do
    n_var="AA_pkg_${i}_name"; pkg="${!n_var}"
    is_package_installed "$pkg" || { echo -e "${RED}NOT HARDENED${RESET}"; exit 0; }
done

echo -e "${GREEN}HARDENED${RESET}"; exit 0  