#!/usr/bin/env bash

NAME="ensure tftp server services are not in use"

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

[ -f "$DPKG_RAM_STORE" ] && source "$DPKG_RAM_STORE"
[ -f "$SERVICES_RAM_STORE" ] && source "$SERVICES_RAM_STORE"

category="tftp"

while IFS= read -r pkg; do
    restrict=$(get_svc "$category" "$pkg" "restrict")
    version=$(get_svc "$category" "$pkg" "version")

    if [[ "$restrict" == "true" ]]; then
        if is_package_installed "$pkg"; then
            while IFS= read -r svc; do
                systemctl stop "$svc" 2>/dev/null
                systemctl disable "$svc" 2>/dev/null
            done < <(get_svc_services "$category" "$pkg")

            apt-get remove --purge -y "$pkg" &>/dev/null
            unset_package "$pkg"
            if is_package_installed "$pkg"; then
                echo -e "${RED}FAILED${RESET}"
                exit 1
            fi
        fi
    elif [[ "$restrict" == "false" ]]; then
        if is_package_installed "$pkg"; then
            if ! is_version_ok "$pkg" "$version"; then
                apt-get upgrade -y "$pkg" &>/dev/null
                if ! is_version_ok "$pkg" "$version"; then
                    echo -e "${RED}FAILED${RESET}"
                    exit 1
                fi
            fi
        fi
    fi
done < <(get_svc_packages "$category")

echo -e "${GREEN}SUCCESS${RESET}"
exit 0