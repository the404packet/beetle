#!/usr/bin/env bash

NAME='ssh login banner audit'
SEVERITY='basic'

flag=1

#check if global banner file is set
if ! sshd -T 2>/dev/null | grep -Pi -- '^banner\h+\/\H+'; then
    flag=0
fi


#check if MATCH block exist
if (( flag )) && \
   grep -Riq '^\s*Match\b' /etc/ssh/sshd_config /etc/ssh/sshd_config.d 2>/dev/null; then

    if ! sshd -T -C user="$USER" 2>/dev/null | \
         grep -Pi -- '^banner\h+\/\H+'; then
        flag=0
    fi
fi


#check banner file exists
if (( flag )); then
    banner_file=$(sshd -T 2>/dev/null | awk '$1=="banner"{print $2}')
    if [[ ! -e "$banner_file" ]]; then
        flag=0
    fi
fi

#ensure file does not disclose OS info  
if (( flag )); then
    os_id=$(grep '^ID=' /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"')

    if grep -Psi -- "(\\\v|\\\r|\\\m|\\\s|\b${os_id}\b)" "$banner_file" 2>/dev/null; then
        flag=0
    fi
fi


if (( flag )); then
    echo -e "${GREEN}HARDENED${RESET}"
else
    echo -e "${RED}NOT HARDENED${RESET}"
fi

exit 0
