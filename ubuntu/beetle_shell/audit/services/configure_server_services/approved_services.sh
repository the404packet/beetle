#!/usr/bin/env bash

NAME="ensure only approved services are listening on a network interface"

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

[ -f "$SERVICES_RAM_STORE" ] && source "$SERVICES_RAM_STORE"

# get all listening services
listening=$(ss -plntu 2>/dev/null)

# get all approved packages from server_services in RAM
approved_ports=()
while IFS= read -r category; do
    while IFS= read -r pkg; do
        restrict=$(get_svc "$category" "$pkg" "restrict")
        if [[ "$restrict" == "false" ]] && is_package_installed "$pkg"; then
            # allowed package — get its ports
            while IFS= read -r svc; do
                port=$(systemctl show "$svc" -p Listen 2>/dev/null | grep -oP ':\K[0-9]+')
                [ -n "$port" ] && approved_ports+=("$port")
            done < <(get_svc_services "$category" "$pkg")
        fi
    done < <(get_svc_packages "$category")
done < <(echo -e "web\nweb_proxy\nmail")

# find non-approved listening ports
not_approved=()
while IFS= read -r line; do
    port=$(echo "$line" | grep -oP ':\K[0-9]+(?=\s)')
    proc=$(echo "$line" | grep -oP 'users:\(\("\K[^"]+')
    [ -z "$port" ] && continue

    approved=false
    for ap in "${approved_ports[@]}"; do
        [[ "$ap" == "$port" ]] && approved=true && break
    done

    $approved || not_approved+=("$proc on port $port")
done < <(echo "$listening" | tail -n +2)

if [[ ${#not_approved[@]} -eq 0 ]]; then
    echo -e "${GREEN}HARDENED${RESET}"
else
    echo -e "${RED}NOT HARDENED${RESET}"
fi

exit 0