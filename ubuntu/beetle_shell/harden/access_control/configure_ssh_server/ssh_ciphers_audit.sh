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

WEAK_CIPHER_PATTERN="${SSHD_WEAK_CIPHER_PATTERN:-3des-cbc|blowfish-cbc|cast128-cbc|aes128-cbc|aes192-cbc|aes256-cbc|arcfour(128|256)?|rijndael-cbc@lysator\.liu\.se}"

# Strong default cipher suite (OpenSSH 8.x+ recommended)
STRONG_CIPHERS="aes128-ctr,aes192-ctr,aes256-ctr,aes128-gcm@openssh.com,aes256-gcm@openssh.com,chacha20-poly1305@openssh.com"

SSHD_CONFIG="/etc/ssh/sshd_config"
flag=1

set_ciphers() {
    local file="$1"
    if grep -Piq '^\s*Ciphers\b' "$file" 2>/dev/null; then
        sed -i "s|^\s*[Cc]iphers\s.*|Ciphers $STRONG_CIPHERS|" "$file"
    else
        echo "Ciphers $STRONG_CIPHERS" >> "$file"
    fi
}

set_ciphers "$SSHD_CONFIG"

if [[ -d /etc/ssh/sshd_config.d ]]; then
    while IFS= read -r -d $'\0' file; do
        if grep -Piq '^\s*Ciphers\b' "$file" 2>/dev/null; then
            sed -i "s|^\s*[Cc]iphers\s.*|Ciphers $STRONG_CIPHERS|" "$file"
        fi
    done < <(find /etc/ssh/sshd_config.d -type f -name "*.conf" -print0)
fi

# Validate — no weak ciphers should appear now
if sshd -T 2>/dev/null | grep -Piq -- \
   "^ciphers\h+\"?([^#\n\r]+,)?(${WEAK_CIPHER_PATTERN})\b"; then
    flag=0
fi

if (( flag )); then
    echo -e "${GREEN}SUCCESS${RESET}"
else
    echo -e "${RED}FAILED${RESET}"
    exit 1
fi

exit 0
