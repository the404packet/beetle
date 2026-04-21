#!/usr/bin/env bash

NAME='ensure pam_unix includes a strong password hashing algorithm'
SEVERITY='basic'

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

[ -f "$SSH_RAM_STORE" ] && source "$SSH_RAM_STORE"

HASH_ALGO="${PAM_UNIX_HASH_ALGO:-yescrypt}"

while IFS= read -r profile; do
    if grep -Piq '\bpam_unix\.so\b' "$profile" 2>/dev/null; then
        # Replace existing hash algo or add yescrypt
        if grep -Piq '\b(md5|bigcrypt|sha256|sha512|blowfish|gost_yescrypt|yescrypt)\b' "$profile" 2>/dev/null; then
            sed -i -E "s/\b(md5|bigcrypt|sha256|sha512|blowfish|gost_yescrypt|yescrypt)\b/${HASH_ALGO}/g" "$profile"
        else
            sed -i -E "s/(pam_unix\.so)/\1 ${HASH_ALGO}/" "$profile"
        fi
        pam-auth-update --enable "$(basename "$profile")" 2>/dev/null
    fi
done < <(find /usr/share/pam-configs -type f 2>/dev/null)

if grep -PH -- '^\h*password\h+([^#\n\r]+)\h+pam_unix\.so\h+([^#\n\r]+\h+)?(sha512|yescrypt)\b' \
   /etc/pam.d/common-password 2>/dev/null | grep -q .; then
    echo -e "${GREEN}SUCCESS${RESET}"
else
    echo -e "${RED}FAILED${RESET}"
    exit 1
fi

exit 0
