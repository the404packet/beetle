#!/usr/bin/env bash

NAME="ensure mail transfer agent is configured for local only mode"

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

[ -f "$DPKG_RAM_STORE" ] && source "$DPKG_RAM_STORE"
[ -f "$SERVICES_RAM_STORE" ] && source "$SERVICES_RAM_STORE"

category="mail"

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

            # check loopback only
            for port in 25 465 587; do
                if ss -plntu | grep -P -- ":$port\b" | \
                   grep -Pvq -- "\h+(127\.0\.0\.1|\[?::1\]?):$port\b"; then
                    echo -e "${RED}NOT HARDENED${RESET}"
                    exit 0
                fi
            done

            if command -v postconf &>/dev/null; then
                interfaces=$(postconf -n inet_interfaces 2>/dev/null | awk '{print $3}')
                if echo "$interfaces" | grep -Pqi '\ball\b'; then
                    echo -e "${RED}NOT HARDENED${RESET}"
                    exit 0
                elif ! echo "$interfaces" | grep -Pqi '(127\.0\.0\.1|::1|loopback-only|loopbackonly)'; then
                    echo -e "${RED}NOT HARDENED${RESET}"
                    exit 0
                fi
            fi
        fi
    fi
done < <(get_svc_packages "$category")

echo -e "${GREEN}HARDENED${RESET}"
exit 0