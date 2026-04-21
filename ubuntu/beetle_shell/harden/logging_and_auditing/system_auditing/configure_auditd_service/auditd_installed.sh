#!/usr/bin/env bash
NAME="ensure auditd packages are installed"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$DPKG_RAM_STORE" ]    && source "$DPKG_RAM_STORE"
[ -f "$LOGGING_RAM_STORE" ] && source "$LOGGING_RAM_STORE" || { echo -e "${RED}FAILED${RESET}"; exit 1; }

count="$AD_pkg_count"
for ((i=0; i<count; i++)); do
    n_var="AD_pkg_${i}_name"; pkg="${!n_var}"
    if ! is_package_installed "$pkg"; then
        apt-get install -y "$pkg" 2>/dev/null \
            || { echo -e "${RED}FAILED${RESET}"; exit 1; }
    fi
done

echo -e "${GREEN}SUCCESS${RESET}"; exit 0