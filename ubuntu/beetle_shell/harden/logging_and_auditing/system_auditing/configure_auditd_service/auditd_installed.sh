#!/usr/bin/env bash
NAME="ensure auditd packages are installed"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$DPKG_RAM_STORE" ]    && source "$DPKG_RAM_STORE"
[ -f "$LOGGING_RAM_STORE" ] && source "$LOGGING_RAM_STORE" || { echo -e "${RED}FAILED${RESET}"; exit 1; }

export DEBIAN_FRONTEND=noninteractive

count="$AD_pkg_count"
for ((i=0; i<count; i++)); do
    n_var="AD_pkg_${i}_name"; pkg="${!n_var}"
    [ -z "$pkg" ] && continue
    if ! is_package_installed "$pkg"; then
        apt-get install -y -q "$pkg" </dev/null >/dev/null 2>&1 || true
    fi
done

failed=0
for ((i=0; i<count; i++)); do
    n_var="AD_pkg_${i}_name"; pkg="${!n_var}"
    [ -z "$pkg" ] && continue
    live_package_installed "$pkg" || failed=1
done

[ "$failed" -eq 0 ] \
    && echo -e "${GREEN}SUCCESS${RESET}" \
    || { echo -e "${RED}FAILED${RESET}"; exit 1; }
exit 0
