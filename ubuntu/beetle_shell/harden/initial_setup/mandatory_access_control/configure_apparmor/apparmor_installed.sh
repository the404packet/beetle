#!/usr/bin/env bash
NAME="ensure AppArmor is installed"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$DPKG_RAM_STORE" ]          && source "$DPKG_RAM_STORE"
[ -f "$INITIAL_SETUP_RAM_STORE" ] && source "$INITIAL_SETUP_RAM_STORE" || { echo -e "${RED}FAILED${RESET}"; exit 1; }

count="$AA_pkg_count"
for ((i=0; i<count; i++)); do
    n_var="AA_pkg_${i}_name"; pkg="${!n_var}"
    if ! is_package_installed "$pkg"; then
        apt-get install -y "$pkg" 2>/dev/null \
            || { echo -e "${RED}FAILED${RESET}"; exit 1; }
    fi
done

echo -e "${GREEN}SUCCESS${RESET}"; exit 0