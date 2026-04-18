#!/usr/bin/env bash

NAME="ensure ftp server services are not in use"

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

[ -f "$DPKG_RAM_STORE" ] && source "$DPKG_RAM_STORE"
[ -f "$SERVICES_RAM_STORE" ] && source "$SERVICES_RAM_STORE"

category="ftp"

while IFS= read -r pkg; do
    restrict=$(get_svc "$category" "$pkg" "restrict")
    version=$(get_svc "$category" "$pkg" "version")

    if [[ "$restrict" == "true" ]]; then
        if is_package_installed "$pkg"; then
            echo -e "${RED}NOT HARDENED${RESET}"
            exit 0
        fi
    elif [[ "$restrict" == "false" ]]; then
        if is_package_installed "$pkg"; then
            if ! is_version_ok "$pkg" "$version"; then
                echo -e "${RED}NOT HARDENED${RESET}"
                exit 0
            fi
        fi
    fi
done < <(get_svc_packages "$category")

echo -e "${GREEN}HARDENED${RESET}"
exit 0