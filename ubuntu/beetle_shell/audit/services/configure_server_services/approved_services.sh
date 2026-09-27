#!/usr/bin/env bash

NAME="ensure only approved services are listening on a network interface"

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

[ -f "$SERVICES_RAM_STORE" ] && source "$SERVICES_RAM_STORE"

# Gather all listening ports
listening=$(ss -plntu 2>/dev/null)

# Gather all "approved" ports — packages with restrict:false that are installed
approved_ports=()
while IFS= read -r category; do
    [ -z "$category" ] && continue
    while IFS= read -r pkg; do
        [ -z "$pkg" ] && continue
        restrict=$(get_svc "$category" "$pkg" "restrict")
        if [[ "$restrict" == "false" ]] && is_package_installed "$pkg"; then
            while IFS= read -r svc; do
                [ -z "$svc" ] && continue
                while IFS= read -r p; do
                    [ -n "$p" ] && approved_ports+=("$p")
                done < <(systemctl show "$svc" -p Listen 2>/dev/null | grep -oP ':\K[0-9]+')
            done < <(get_svc_services "$category" "$pkg")
        fi
    done < <(get_svc_packages "$category")
done < <(echo -e "web\nweb_proxy\nmail")

# Find non-approved listening ports
not_approved=()
while IFS= read -r line; do
    port=$(echo "$line" | grep -oP ':\K[0-9]+(?=\s)')
    proc=$(echo "$line" | grep -oP 'users:\(\("\K[^"]+')
    [ -z "$port" ] && continue

    approved=false
    for ap in "${approved_ports[@]}"; do
        [[ "$ap" == "$port" ]] && approved=true && break
    done

    $approved || not_approved+=("${proc:-unknown} on port $port")
done < <(echo "$listening" | tail -n +2)

if [[ ${#not_approved[@]} -eq 0 ]]; then
    echo -e "${GREEN}HARDENED${RESET}"
else
    echo -e "${RED}NOT HARDENED${RESET}"
fi

exit 0
