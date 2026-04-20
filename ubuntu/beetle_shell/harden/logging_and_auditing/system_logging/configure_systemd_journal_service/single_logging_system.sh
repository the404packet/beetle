#!/usr/bin/env bash
NAME="ensure only one logging system is in use"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
# Policy: prefer journald; disable rsyslog if both are active
[ -f "$LOGGING_RAM_STORE" ] && source "$LOGGING_RAM_STORE"

rsyslog_active=$(systemctl is-active rsyslog 2>/dev/null)
journald_active=$(systemctl is-active systemd-journald 2>/dev/null)

if [ "$rsyslog_active" = "active" ] && [ "$journald_active" = "active" ]; then
    systemctl stop    rsyslog 2>/dev/null
    systemctl disable rsyslog 2>/dev/null
    systemctl mask    rsyslog 2>/dev/null
fi

journald_active=$(systemctl is-active systemd-journald 2>/dev/null)
[ "$journald_active" != "active" ] && { echo -e "${RED}FAILED${RESET}"; exit 1; }

echo -e "${GREEN}SUCCESS${RESET}"; exit 0