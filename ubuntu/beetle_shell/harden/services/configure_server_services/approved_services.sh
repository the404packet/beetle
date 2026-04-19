#!/usr/bin/env bash

NAME="ensure only approved services are listening on a network interface"

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

[ -f "$DPKG_RAM_STORE" ] && source "$DPKG_RAM_STORE"
[ -f "$SERVICES_RAM_STORE" ] && source "$SERVICES_RAM_STORE"

listening_lines=()
while IFS= read -r line; do
    port=$(echo "$line" | grep -oP ':\K[0-9]+(?=\s)')
    proc=$(echo "$line" | grep -oP 'users:\(\("\K[^"]+')
    pid=$(echo "$line"  | grep -oP 'pid=\K[0-9]+')
    [ -z "$port" ] && continue
    listening_lines+=("$port|$proc|$pid")
done < <(ss -plntu 2>/dev/null | tail -n +2)

failed=false

for entry in "${listening_lines[@]}"; do
    port="${entry%%|*}"
    rest="${entry#*|}"
    proc="${rest%%|*}"
    pid="${rest##*|}"

    echo ""
    echo -e "${RED}Non-approved service detected:${RESET}"
    echo "  Process : $proc"
    echo "  Port    : $port"
    echo "  PID     : $pid"

    # find package owning this process
    pkg=""
    if [ -n "$pid" ]; then
        exe=$(readlink -f /proc/$pid/exe 2>/dev/null)
        pkg=$(dpkg -S "$exe" 2>/dev/null | cut -d: -f1)
    fi

    echo ""
    echo "  Package : ${pkg:-unknown}"
    echo ""
    echo -e "  Press ${GREEN}ENTER${RESET} to stop and remove service (default)"
    echo -e "  Type   ${RED}no${RESET}   to skip and mark as FAILED"
    read -r -p "  Choice: " choice

    if [[ "$choice" == "no" ]]; then
        echo -e "${RED}SKIPPED${RESET} - $proc on port $port marked as failed"
        failed=true
        continue
    fi

    # default — stop and purge
    # find service unit
    svc_unit=$(systemctl list-units --type=service --state=running 2>/dev/null | \
               grep -i "$proc" | awk '{print $1}' | head -1)
    sock_unit=$(systemctl list-units --type=socket --state=running 2>/dev/null | \
                grep -i "$proc" | awk '{print $1}' | head -1)

    [ -n "$svc_unit" ]  && systemctl stop "$svc_unit" 2>/dev/null
    [ -n "$sock_unit" ] && systemctl stop "$sock_unit" 2>/dev/null

    if [ -n "$pkg" ]; then
        echo -e "  Removing package: $pkg"
        apt-get remove --purge -y "$pkg" &>/dev/null

        if dpkg-query -s "$pkg" &>/dev/null; then
            # has dependency — mask instead
            echo -e "  Package has dependencies — masking service instead"
            [ -n "$svc_unit" ]  && systemctl mask "$svc_unit" 2>/dev/null
            [ -n "$sock_unit" ] && systemctl mask "$sock_unit" 2>/dev/null
        fi
    else
        # no package found — just mask
        [ -n "$svc_unit" ]  && systemctl mask "$svc_unit" 2>/dev/null
        [ -n "$sock_unit" ] && systemctl mask "$sock_unit" 2>/dev/null
    fi
done

if $failed; then
    echo -e "${RED}FAILED${RESET}"
    exit 1
fi

echo -e "${GREEN}SUCCESS${RESET}"
exit 0