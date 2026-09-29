#!/usr/bin/env bash
NAME="ensure filesystem integrity is regularly checked"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$LOGGING_RAM_STORE" ] && source "$LOGGING_RAM_STORE" || { echo -e "${RED}FAILED${RESET}"; exit 1; }

[ -z "$AI_timer" ]   && { echo -e "${RED}FAILED${RESET} (timer not set)"; exit 1; }
[ -z "$AI_service" ] && { echo -e "${RED}FAILED${RESET} (service not set)"; exit 1; }

export DEBIAN_FRONTEND=noninteractive

if ! dpkg-query -W -f='${Status}' aide-common 2>/dev/null | grep -q "install ok installed"; then
    apt-get install -y -q aide aide-common </dev/null >/dev/null 2>&1 || true
fi

systemctl unmask "$AI_timer" "$AI_service" 2>/dev/null || true
systemctl --now enable "$AI_timer" 2>/dev/null

timer_active=$(systemctl is-active "$AI_timer" 2>/dev/null)
if [ "$timer_active" != "active" ]; then
    echo -e "${RED}FAILED${RESET} (timer $AI_timer not active)"
    exit 1
fi

echo -e "${GREEN}SUCCESS${RESET}"
exit 0
