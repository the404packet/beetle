#!/usr/bin/env bash

NAME='sshd ciphers config'
SEVERITY='basic'

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

if ! is_package_installed "openssh-server"; then
    echo -e "${GREEN}HARDENED${RESET}"
    exit 0
fi

[ -f "$SSH_RAM_STORE" ] && source "$SSH_RAM_STORE"

# Load weak cipher list from RAM store (set by load_json_permissions for access_control.json)
# Env var: SSHD_weak_ciphers (pipe-separated list built at load time)
# Falls back to hardcoded pattern if not set
WEAK_CIPHER_PATTERN="${SSHD_WEAK_CIPHER_PATTERN:-3des-cbc|blowfish-cbc|cast128-cbc|aes128-cbc|aes192-cbc|aes256-cbc|arcfour(128|256)?|rijndael-cbc@lysator\.liu\.se}"

flag=1

# Check global effective configuration
if sshd -T 2>/dev/null | grep -Piq -- \
   "^ciphers\h+\"?([^#\n\r]+,)?(${WEAK_CIPHER_PATTERN})\b"; then
    flag=0
fi

# Re-check with Match block context if present
if (( flag )) && \
   grep -Riq '^\s*Match\b' /etc/ssh/sshd_config /etc/ssh/sshd_config.d 2>/dev/null; then
    if sshd -T -C user="$USER" 2>/dev/null | grep -Piq -- \
       "^ciphers\h+\"?([^#\n\r]+,)?(${WEAK_CIPHER_PATTERN})\b"; then
        flag=0
    fi
fi

if (( flag )); then
    echo -e "${GREEN}HARDENED${RESET}"
else
    echo -e "${RED}NOT HARDENED${RESET}"
fi

exit 0
