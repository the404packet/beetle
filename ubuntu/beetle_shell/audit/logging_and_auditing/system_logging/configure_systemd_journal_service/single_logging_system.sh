#!/usr/bin/env bash
NAME="ensure only one logging system is in use"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"

rsyslog_active=$(systemctl is-active rsyslog          2>/dev/null)
journald_active=$(systemctl is-active systemd-journald 2>/dev/null)

both=0
[ "$rsyslog_active"  = "active" ] && ((both++))
[ "$journald_active" = "active" ] && ((both++))

if [ "$both" -eq 1 ]; then
    echo -e "${GREEN}HARDENED${RESET}"
elif [ "$both" -eq 0 ]; then
    echo -e "${RED}NOT HARDENED${RESET}"
else
    echo -e "${RED}NOT HARDENED${RESET}"
fi
exit 0