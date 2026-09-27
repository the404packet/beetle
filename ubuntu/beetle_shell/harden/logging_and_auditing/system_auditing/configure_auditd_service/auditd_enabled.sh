#!/usr/bin/env bash
NAME="ensure auditd service is enabled and active"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$LOGGING_RAM_STORE" ] && source "$LOGGING_RAM_STORE" || { echo -e "${RED}FAILED${RESET}"; exit 1; }

[ -z "$AD_service" ] && { echo -e "${RED}FAILED${RESET} (service not set)"; exit 1; }

export DEBIAN_FRONTEND=noninteractive
if ! dpkg-query -W -f='${Status}' auditd 2>/dev/null | grep -q "install ok installed"; then
    apt-get install -y -q auditd audispd-plugins </dev/null >/dev/null 2>&1 || true
fi

systemctl unmask "$AD_service" 2>/dev/null || true
systemctl enable "$AD_service" 2>/dev/null || true
systemctl start  "$AD_service" 2>/dev/null || true

enabled=$(systemctl is-enabled "$AD_service" 2>/dev/null)
active=$(systemctl  is-active  "$AD_service" 2>/dev/null)

[[ "$enabled" == "enabled" || "$enabled" == "enabled-runtime" ]] && [ "$active" = "active" ] \
    && echo -e "${GREEN}SUCCESS${RESET}" \
    || { echo -e "${RED}FAILED${RESET}"; exit 1; }
exit 0
