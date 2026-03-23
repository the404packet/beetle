#!/usr/bin/env bash

NAME="sshd kexalgorithm config"
SEVERITY="basic"

flag=1
# Check for weak ciphers
if sshd -T 2>/dev/null | grep -Piq -- \
'^kexalgorithms\h+([^#\n\r]+,)?(diffie-hellman-group1-sha1|diffie-hellman-group14-sha1|diffie-hellman-group-exchange-sha1)\b'; then
    flag=0
fi


# If Match block exists
if (( flag )) && \
   grep -Riq '^\s*Match\b' /etc/ssh/sshd_config /etc/ssh/sshd_config.d 2>/dev/null; then

    if sshd -T 2>/dev/null | grep -Piq -- \
    '^kexalgorithms\h+([^#\n\r]+,)?(diffie-hellman-group1-sha1|diffie-hellman-group14-sha1|diffie-hellman-group-exchange-sha1)\b'; then
        flag=0
    fi

fi



if (( flag )); then
    echo -e "${GREEN}HARDENED${RESET}"
else
    echo -e "${RED}NOT HARDENED${RESET}"
fi

exit 0