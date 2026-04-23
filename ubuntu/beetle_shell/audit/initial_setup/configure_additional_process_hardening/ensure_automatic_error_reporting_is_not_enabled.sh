#!/usr/bin/env bash
NAME='ensure automatic error reporting is not enabled'
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$INITIAL_SETUP_RAM_STORE" ] && source "$INITIAL_SETUP_RAM_STORE"
[ -f "$DPKG_RAM_STORE" ]          && source "$DPKG_RAM_STORE"

# If apport not installed, trivially hardened
if ! is_package_installed "apport"; then
    echo -e "${GREEN}HARDENED${RESET}"; exit 0
fi

flag=1
# enabled= must be 0
grep -Psi -- '^\h*enabled\h*=\h*[^0]\b' "$PH_apport_config" 2>/dev/null \
    | grep -q . && flag=0
# service must not be active
systemctl is-active "$PH_apport_service" 2>/dev/null | grep -q '^active' && flag=0

(( flag )) && echo -e "${GREEN}HARDENED${RESET}" || echo -e "${RED}NOT HARDENED${RESET}"
exit 0