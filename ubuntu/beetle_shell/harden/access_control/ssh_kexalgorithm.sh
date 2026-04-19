#!/usr/bin/env bash

NAME='sshd kexalgorithm config'
SEVERITY='basic'

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

[ -f "$PERM_RAM_STORE" ] && source "$PERM_RAM_STORE"

WEAK_KEX_PATTERN="${SSHD_WEAK_KEX_PATTERN:-diffie-hellman-group1-sha1|diffie-hellman-group14-sha1|diffie-hellman-group-exchange-sha1}"

STRONG_KEX="curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group14-sha256,diffie-hellman-group16-sha512,diffie-hellman-group18-sha512,ecdh-sha2-nistp521,ecdh-sha2-nistp384,ecdh-sha2-nistp256,diffie-hellman-group-exchange-sha256"

SSHD_CONFIG="/etc/ssh/sshd_config"
flag=1

set_kex() {
    local file="$1"
    if grep -Piq '^\s*KexAlgorithms\b' "$file" 2>/dev/null; then
        sed -i "s|^\s*[Kk]ex[Aa]lgorithms\s.*|KexAlgorithms $STRONG_KEX|" "$file"
    else
        echo "KexAlgorithms $STRONG_KEX" >> "$file"
    fi
}

set_kex "$SSHD_CONFIG"

if [[ -d /etc/ssh/sshd_config.d ]]; then
    while IFS= read -r -d $'\0' file; do
        if grep -Piq '^\s*KexAlgorithms\b' "$file" 2>/dev/null; then
            sed -i "s|^\s*[Kk]ex[Aa]lgorithms\s.*|KexAlgorithms $STRONG_KEX|" "$file"
        fi
    done < <(find /etc/ssh/sshd_config.d -type f -name "*.conf" -print0)
fi

# Validate
if sshd -T 2>/dev/null | grep -Piq -- \
   "^kexalgorithms\h+([^#\n\r]+,)?(${WEAK_KEX_PATTERN})\b"; then
    flag=0
fi

if (( flag )); then
    echo -e "${GREEN}SUCCESS${RESET}"
else
    echo -e "${RED}FAILED${RESET}"
    exit 1
fi

exit 0
