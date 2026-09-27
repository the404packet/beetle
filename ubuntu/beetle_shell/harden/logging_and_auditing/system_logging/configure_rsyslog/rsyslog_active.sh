#!/usr/bin/env bash
NAME="ensure rsyslog service is enabled and active"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$LOGGING_RAM_STORE" ] && source "$LOGGING_RAM_STORE" || { echo -e "${RED}FAILED${RESET}"; exit 1; }

[ "${LJ_preferred_logging_system:-journald}" != "rsyslog" ] && { echo -e "${GREEN}SUCCESS${RESET}"; exit 0; }

[ -z "$RS_service" ] && { echo -e "${RED}FAILED${RESET}"; exit 1; }

export DEBIAN_FRONTEND=noninteractive

if ! dpkg-query -W -f='${Status}' "$RS_package" 2>/dev/null | grep -q "install ok installed"; then
    apt-get install -y -q "$RS_package" </dev/null >/dev/null 2>&1 || true
fi

systemctl unmask "$RS_service" 2>/dev/null || true
systemctl enable "$RS_service" 2>/dev/null || true
systemctl start  "$RS_service" 2>/dev/null || true

enabled=$(systemctl is-enabled "$RS_service" 2>/dev/null)
active=$(systemctl  is-active  "$RS_service" 2>/dev/null)

[[ "$enabled" == "enabled" || "$enabled" == "enabled-runtime" ]] && [ "$active" = "active" ] \
    && echo -e "${GREEN}SUCCESS${RESET}" \
    || { echo -e "${RED}FAILED${RESET}"; exit 1; }
exit 0
