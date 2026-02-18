#!/usr/bin/env bash

NAME='sshd ignoreRhosts set to yes'
SEVERITY='basic'

flag=1


#global config
if  sshd -T 2>/dev/null | grep -Piq '^ignorerhosts\s+no'; then
    flag=0 # set wrong
fi
    

#if MATCH exists 
if (( flag )) && grep -Riq '^\s*Match\b' /etc/ssh/sshd_config /etc/ssh/sshd_config.d 2>/dev/null; then
    if ! sshd -T -C user="$USER" 2>/dev/null | grep -Piq '^ignorerhosts\s+no'; then
        flag=0
    fi
fi

if (( flag )); then
    echo -e "${GREEN}HARDENED${RESET}"
else
    echo -e "${RED}NOT HARDENED${RESET}"
fi

exit 0