#!/usr/bin/env bash

NAME="ensure only approved services are listening on a network interface"

GREEN="\e[32m"
RED="\e[31m"
YELLOW="\e[33m"
RESET="\e[0m"

[ -f "$DPKG_RAM_STORE" ] && source "$DPKG_RAM_STORE"
[ -f "$SERVICES_RAM_STORE" ] && source "$SERVICES_RAM_STORE"

# ── Collect listening services ──
listening_lines=()
while IFS= read -r line; do
    port=$(echo "$line" | grep -oP ':\K[0-9]+(?=\s)')
    proc=$(echo "$line" | grep -oP 'users:\(\("\K[^"]+')
    pid=$(echo  "$line" | grep -oP 'pid=\K[0-9]+')
    [ -z "$port" ] && continue
    listening_lines+=("$port|$proc|$pid")
done < <(ss -plntu 2>/dev/null | tail -n +2)

if [[ "${#listening_lines[@]}" -eq 0 ]]; then
    echo -e "${GREEN}SUCCESS${RESET}"
    exit 0
fi

# ── Non-interactive: this is a CIS *manual* control, we cannot decide ──
# "Only approved services listening" requires a human to know which
# services are approved on this host. Without a terminal, we cannot ask.
if ! { [ -t 0 ] && [ -c /dev/tty ]; }; then
    echo -e "${RED}FAILED${RESET}"
    echo "  Non-interactive mode: cannot determine which services are approved."
    echo "  Listening services detected:"
    for entry in "${listening_lines[@]}"; do
        echo "    - $entry"
    done
    echo "  Run 'sudo beetle harden services strict' interactively to review each one."
    exit 1
fi

# ── Interactive: review each listening service ──
failed=false

for entry in "${listening_lines[@]}"; do
    port="${entry%%|*}"
    rest="${entry#*|}"
    proc="${rest%%|*}"
    pid="${rest##*|}"
    [ -z "$port" ] && continue

    echo ""
    echo -e "${YELLOW}Service listening on a network interface:${RESET}"
    echo "  Process : $proc"
    echo "  Port    : $port"
    echo "  PID     : $pid"

    pkg=""
    if [ -n "$pid" ]; then
        exe=$(readlink -f "/proc/$pid/exe" 2>/dev/null)
        pkg=$(dpkg -S "$exe" 2>/dev/null | cut -d: -f1)
    fi
    echo "  Package : ${pkg:-unknown}"
    echo ""

    while true; do
        echo -e "  Stop and remove this service? [${GREEN}y${RESET}/${RED}n${RESET}] (default: n): "
        read -r choice </dev/tty
        choice="${choice:-n}"
        case "${choice,,}" in
            y|yes) choice="y"; break ;;
            n|no)  choice="n"; break ;;
            *) echo -e "${RED}Please answer y or n.${RESET}" ;;
        esac
    done

    if [[ "$choice" == "n" ]]; then
        echo -e "  ${YELLOW}Skipped — $proc on port $port left untouched${RESET}"
        failed=true
        continue
    fi

    # User confirmed — stop and remove
    svc_unit=$(systemctl list-units --type=service --state=running 2>/dev/null | \
               awk -v p="$proc" 'tolower($0) ~ tolower(p) {print $1; exit}')
    sock_unit=$(systemctl list-units --type=socket --state=running 2>/dev/null | \
                awk -v p="$proc" 'tolower($0) ~ tolower(p) {print $1; exit}')

    [ -n "$svc_unit" ]  && systemctl stop "$svc_unit"  2>/dev/null
    [ -n "$sock_unit" ] && systemctl stop "$sock_unit" 2>/dev/null

    if [ -n "$pkg" ]; then
        echo -e "  Removing package: $pkg"
        apt-get remove --purge -y "$pkg" </dev/null &>/dev/null

        if live_package_installed "$pkg"; then
            echo -e "  Package still present (dependencies or essential) — masking service"
            [ -n "$svc_unit" ]  && systemctl mask "$svc_unit"  2>/dev/null
            [ -n "$sock_unit" ] && systemctl mask "$sock_unit" 2>/dev/null
        fi
    else
        [ -n "$svc_unit" ]  && systemctl mask "$svc_unit"  2>/dev/null
        [ -n "$sock_unit" ] && systemctl mask "$sock_unit" 2>/dev/null
    fi
done

if $failed; then
    echo -e "${RED}FAILED${RESET}"
    exit 1
fi

echo -e "${GREEN}SUCCESS${RESET}"
exit 0