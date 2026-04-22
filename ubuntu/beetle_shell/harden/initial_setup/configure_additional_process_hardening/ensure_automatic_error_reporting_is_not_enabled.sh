#!/usr/bin/env bash
NAME='ensure automatic error reporting is not enabled'
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$INITIAL_SETUP_RAM_STORE" ] && source "$INITIAL_SETUP_RAM_STORE"
[ -f "$DPKG_RAM_STORE" ]          && source "$DPKG_RAM_STORE"

if ! is_package_installed "apport"; then
    echo -e "${GREEN}SUCCESS${RESET}"; exit 0
fi

# Set enabled=0
if grep -Pq '^\s*enabled\s*=' "$PH_apport_config" 2>/dev/null; then
    sed -i 's|^\s*enabled\s*=.*|enabled=0|' "$PH_apport_config"
else
    echo "enabled=0" >> "$PH_apport_config"
fi

systemctl stop "$PH_apport_service"  2>/dev/null
systemctl mask "$PH_apport_service"  2>/dev/null

# Validate
flag=1
grep -Psi -- '^\h*enabled\h*=\h*[^0]\b' "$PH_apport_config" 2>/dev/null \
    | grep -q . && flag=0
systemctl is-active "$PH_apport_service" 2>/dev/null | grep -q '^active' && flag=0

(( flag )) && { echo -e "${GREEN}SUCCESS${RESET}"; exit 0; } || { echo -e "${RED}FAILED${RESET}"; exit 1; }