#!/usr/bin/env bash

NAME="ensure dovecot IMAP and POP3 services are not installed or disabled"
SEVERITY="basic"

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

output=""

# Check if either package is installed
if dpkg-query -s dovecot-imapd &>/dev/null || dpkg-query -s dovecot-pop3d &>/dev/null; then

    # If installed, check dovecot service and socket state
    enabled=$(systemctl is-enabled dovecot.service dovecot.socket 2>/dev/null | grep enabled)
    active=$(systemctl is-active dovecot.service dovecot.socket 2>/dev/null | grep '^active')

    if [[ -n "$enabled" ]] || [[ -n "$active" ]]; then
        output="dovecot packages installed and dovecot.service or dovecot.socket is enabled/active"
    fi
fi

if [[ -z "$output" ]]; then
    echo -e "${GREEN}HARDENED${RESET}"
else
    echo -e "${RED}NOT HARDENED${RESET}"
    echo "$output"
fi

exit 0
