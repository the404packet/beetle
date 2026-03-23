#!/usr/bin/env bash

NAME='ensure sshd client alive interval and count max are configured'
SEVERITY='basic'

flag=1

# Check global  configuration
while read -r key value; do
    case "$key" in
        clientaliveinterval|clientalivecountmax)
            (( value > 0 )) || flag=0
            ;;
    esac
done < <(sshd -T 2>/dev/null | grep -Pi '(clientaliveinterval|clientalivecountmax)')


# IF Match Block exists 
if (( flag )) && \
   grep -Riq '^\s*Match\b' /etc/ssh/sshd_config /etc/ssh/sshd_config.d 2>/dev/null; then

    while read -r key value; do
        case "$key" in
            clientaliveinterval|clientalivecountmax)
                (( value > 0 )) || flag=0
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
