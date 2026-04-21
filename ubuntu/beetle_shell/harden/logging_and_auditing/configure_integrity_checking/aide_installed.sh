#!/usr/bin/env bash
NAME="ensure AIDE is installed"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$DPKG_RAM_STORE" ]    && source "$DPKG_RAM_STORE"
[ -f "$LOGGING_RAM_STORE" ] && source "$LOGGING_RAM_STORE" || { echo -e "${RED}FAILED${RESET}"; exit 1; }

count="$AI_pkg_count"
for ((i=0; i<count; i++)); do
    n_var="AI_pkg_${i}_name"; pkg="${!n_var}"
    if ! is_package_installed "$pkg"; then
        apt-get install -y "$pkg" 2>/dev/null \
            || { echo -e "${RED}FAILED${RESET}"; exit 1; }
    fi
done

# init db if not present
if [ ! -f "$AI_db_active" ]; then
    aideinit 2>/dev/null
    [ -f "$AI_db_init" ] && mv "$AI_db_init" "$AI_db_active" 2>/dev/null
fi

[ -f "$AI_db_active" ] \
    && echo -e "${GREEN}SUCCESS${RESET}" \
    || { echo -e "${RED}FAILED${RESET}"; exit 1; }
exit 0