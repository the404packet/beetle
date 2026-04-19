#!/usr/bin/env bash

NAME='sshd MACs config'
SEVERITY='basic'

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

[ -f "$PERM_RAM_STORE" ] && source "$PERM_RAM_STORE"

WEAK_MAC_PATTERN="${SSHD_WEAK_MAC_PATTERN:-hmac-md5|hmac-md5-96|hmac-ripemd160|hmac-sha1-96|umac-64@openssh\.com|hmac-md5-etm@openssh\.com|hmac-md5-96-etm@openssh\.com|hmac-ripemd160-etm@openssh\.com|hmac-sha1-96-etm@openssh\.com|umac-64-etm@openssh\.com|umac-128-etm@openssh\.com}"

STRONG_MACS="hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,hmac-sha2-512,hmac-sha2-256"

SSHD_CONFIG="/etc/ssh/sshd_config"
flag=1

if grep -Piq '^\s*MACs\b' "$SSHD_CONFIG" 2>/dev/null; then
    sed -i "s|^\s*[Mm][Aa][Cc]s\s.*|MACs $STRONG_MACS|" "$SSHD_CONFIG"
else
    echo "MACs $STRONG_MACS" >> "$SSHD_CONFIG"
fi

if [[ -d /etc/ssh/sshd_config.d ]]; then
    while IFS= read -r -d $'\0' file; do
        if grep -Piq '^\s*MACs\b' "$file" 2>/dev/null; then
            sed -i "s|^\s*[Mm][Aa][Cc]s\s.*|MACs $STRONG_MACS|" "$file"
        fi
    done < <(find /etc/ssh/sshd_config.d -type f -name "*.conf" -print0)
fi

# Validate
if sshd -T 2>/dev/null | grep -Piq -- \
   "macs\h+.*\b(${WEAK_MAC_PATTERN})\b"; then
    flag=0
fi

if (( flag )); then
    echo -e "${GREEN}SUCCESS${RESET}"
else
    echo -e "${RED}FAILED${RESET}"
    exit 1
fi

exit 0
