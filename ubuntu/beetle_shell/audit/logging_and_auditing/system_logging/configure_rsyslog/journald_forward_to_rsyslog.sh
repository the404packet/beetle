#!/usr/bin/env bash
NAME="ensure journald is configured to send logs to rsyslog"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$LOGGING_RAM_STORE" ] && source "$LOGGING_RAM_STORE" || { echo -e "${RED}NOT HARDENED${RESET}"; exit 0; }

actual=$("$(readlink -f /bin/systemd-analyze)" cat-config systemd/journald.conf 2>/dev/null \
         | grep -Ps "^\s*ForwardToSyslog\s*=" | tail -1 \
         | awk -F= '{print $2}' | tr -d ' ')

[ "$actual" = "yes" ] \
    && echo -e "${GREEN}HARDENED${RESET}" \
    || echo -e "${RED}NOT HARDENED${RESET}"
exit 0