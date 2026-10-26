#!/usr/bin/env bash

NAME="ensure systemd-timesyncd is enabled and running"

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

[ -f "$DPKG_RAM_STORE" ] && source "$DPKG_RAM_STORE"
[ -f "$SERVICES_RAM_STORE" ] && source "$SERVICES_RAM_STORE"

daemon_count="${TS_daemon_count:-0}"

# ── If some other time sync daemon is active, timesyncd is not relevant ──
other_active=""
for ((i=0; i<daemon_count; i++)); do
    name_var="TS_daemon_${i}_name"
    svc_var="TS_daemon_${i}_service"
    name="${!name_var}"
    svc="${!svc_var}"
    [ -z "$svc" ] && continue

    [ "$name" == "systemd-timesyncd" ] && continue

    if systemctl is-active "$svc" >/dev/null 2>&1; then
        other_active="$name"
        break
    fi
done

if [ -n "$other_active" ]; then
    echo -e "${GREEN}HARDENED${RESET}"
    exit 0
fi

# ── If timesyncd is not running at all, not relevant ──
is_enabled=$(systemctl is-enabled systemd-timesyncd.service 2>/dev/null)
is_active=$(systemctl is-active   systemd-timesyncd.service 2>/dev/null)

if [[ "$is_enabled" != "enabled" ]] && [[ "$is_active" != "active" ]]; then
    echo -e "${GREEN}HARDENED${RESET}"
    exit 0
fi

if [[ "$is_enabled" == "enabled" ]] && [[ "$is_active" == "active" ]]; then
    echo -e "${GREEN}HARDENED${RESET}"
else
    echo -e "${RED}NOT HARDENED${RESET}"
fi

exit 0
