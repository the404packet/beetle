#!/usr/bin/env bash

NAME="ensure ftp client is not installed"

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

[ -f "$DPKG_RAM_STORE" ] && source "$DPKG_RAM_STORE"
[ -f "$SERVICES_RAM_STORE" ] && source "$SERVICES_RAM_STORE"

export DEBIAN_FRONTEND=noninteractive

category="ftp_client"

while IFS= read -r pkg; do
    [ -z "$pkg" ] && continue
    restrict=$(get_svc "$category" "$pkg" "restrict")

    if [[ "$restrict" == "true" ]]; then
        if is_package_installed "$pkg"; then
            apt-get remove --purge -y -q "$pkg" </dev/null >/dev/null 2>&1 || true
            unset_package "$pkg"

            if live_package_installed "$pkg"; then
                echo -e "${RED}FAILED${RESET}"
                exit 1
            fi
        fi
    fi
done < <(get_svc_packages "$category")

echo -e "${GREEN}SUCCESS${RESET}"
exit 0