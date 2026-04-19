#!/usr/bin/env bash

NAME="ensure ldap client is not installed"

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

[ -f "$DPKG_RAM_STORE" ] && source "$DPKG_RAM_STORE"
[ -f "$SERVICES_RAM_STORE" ] && source "$SERVICES_RAM_STORE"

category="ldap_client"

while IFS= read -r pkg; do
    restrict=$(get_svc "$category" "$pkg" "restrict")

    if [[ "$restrict" == "true" ]]; then
        if is_package_installed "$pkg"; then
            apt-get remove --purge -y "$pkg" &>/dev/null
            unset_package "$pkg"

            if is_package_installed "$pkg"; then
                echo -e "${RED}FAILED${RESET}"
                exit 1
            fi
        fi
    fi
done < <(get_svc_packages "$category")

echo -e "${GREEN}SUCCESS${RESET}"
exit 0