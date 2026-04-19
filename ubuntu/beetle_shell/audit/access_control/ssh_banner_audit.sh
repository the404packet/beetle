#!/usr/bin/env bash

NAME='ssh login banner audit'
SEVERITY='basic'

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

flag=1

# Check if a global banner path is set
if ! sshd -T 2>/dev/null | grep -Pi -- '^banner\h+\/\H+'; then
    flag=0
fi

# If Match blocks exist, verify banner is also applied in that context
if (( flag )) && \
   grep -Riq '^\s*Match\b' /etc/ssh/sshd_config /etc/ssh/sshd_config.d 2>/dev/null; then
    if ! sshd -T -C user="$USER" 2>/dev/null | \
         grep -Pi -- '^banner\h+\/\H+'; then
        flag=0
    fi
fi

# Verify the banner file actually exists
if (( flag )); then
    banner_file=$(sshd -T 2>/dev/null | awk '$1=="banner"{print $2}')
    if [[ ! -e "$banner_file" ]]; then
        flag=0
    fi
fi

# Ensure banner does not disclose OS information
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
