#!/usr/bin/env bash

NAME='ensure sshd client alive interval and count max are configured'
SEVERITY='basic'

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

[ -f "$PERM_RAM_STORE" ] && source "$PERM_RAM_STORE"

INTERVAL_MIN="${SSHD_CLIENTALIVEINTERVAL_MIN:-1}"
COUNTMAX_MIN="${SSHD_CLIENTALIVECOUNTMAX_MIN:-1}"

flag=1

# Check global configuration
while read -r key value; do
    case "$key" in
        clientaliveinterval)
            (( value >= INTERVAL_MIN )) || flag=0
            ;;
        clientalivecountmax)
            (( value >= COUNTMAX_MIN )) || flag=0
            ;;
    esac
done < <(sshd -T 2>/dev/null | grep -Pi '(clientaliveinterval|clientalivecountmax)')

# Re-check with Match block context if present
if (( flag )) && \
   grep -Riq '^\s*Match\b' /etc/ssh/sshd_config /etc/ssh/sshd_config.d 2>/dev/null; then
    while read -r key value; do
        case "$key" in
            clientaliveinterval)
                (( value >= INTERVAL_MIN )) || flag=0
                ;;
            clientalivecountmax)
                (( value >= COUNTMAX_MIN )) || flag=0
                ;;
        esac
    done < <(sshd -T -C user="$USER" 2>/dev/null | grep -Pi '(clientaliveinterval|clientalivecountmax)')
fi

if (( flag )); then
    echo -e "${GREEN}HARDENED${RESET}"
else
    echo -e "${RED}NOT HARDENED${RESET}"
fi

exit 0
