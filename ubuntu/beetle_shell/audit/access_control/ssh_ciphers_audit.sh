#!/usr/bin/env bash

NAME='sshd ciphers config'
SEVERITY="basic"


flag=1

# Check for weak ciphers in effective configuration
if sshd -T 2>/dev/null | grep -Piq -- \
'^ciphers\h+"?([^#\n\r]+,)?((3des|blowfish|cast128|aes(128|192|256))-cbc|arcfour(128|256)?|rijndael-cbc@lysator\.liu\.se)\b'; then
    flag=0
fi


# IF Match Block exists → re-check with connection context
if (( flag )) && \
   grep -Riq '^\s*Match\b' /etc/ssh/sshd_config /etc/ssh/sshd_config.d 2>/dev/null; then

    if sshd -T -C user="$USER" 2>/dev/null | grep -Piq -- \
'^ciphers\h+"?([^#\n\r]+,)?((3des|blowfish|cast128|aes(128|192|256))-cbc|arcfour(128|256)?|rijndael-cbc@lysator\.liu\.se)\b'; then
        flag=0
    fi
fi


if (( flag )); then
    echo -e "${GREEN}HARDENED${RESET}"
else
    echo -e "${RED}NOT HARDENED${RESET}"
fi

exit 0