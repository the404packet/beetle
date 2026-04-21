#!/usr/bin/env bash
NAME="ensure events that modify the sudo log file are collected"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$LOGGING_RAM_STORE" ] && source "$LOGGING_RAM_STORE" || { echo -e "${RED}NOT HARDENED${RESET}"; exit 0; }

sudo_log=$(grep -r logfile /etc/sudoers* 2>/dev/null \
           | sed -e 's/.*logfile=//;s/,.*//' -e 's/"//g' | head -1)

if [ -z "$sudo_log" ]; then
    echo -e "${RED}NOT HARDENED${RESET}"; exit 0
fi

grep -qrF -- "-w ${sudo_log} -p wa" "$AR_rules_dir"/ 2>/dev/null \
    && auditctl -l 2>/dev/null | grep -qF "$sudo_log" \
    && echo -e "${GREEN}HARDENED${RESET}" \
    || echo -e "${RED}NOT HARDENED${RESET}"
exit 0