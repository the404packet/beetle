#!/usr/bin/env bash

NAME="ensure password failed attempts lockout is configured"
SEVERITY='basic'

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

[ -f "$SSH_RAM_STORE" ] && source "$SSH_RAM_STORE"

MAX_DENY="${PAM_FAILLOCK_DENY_MAX:-5}"
FAILLOCK_CONF="/etc/security/faillock.conf"

# Set deny in faillock.conf
if grep -Piq '^\h*deny\h*=' "$FAILLOCK_CONF" 2>/dev/null; then
    sed -i "s|^\h*deny\h*=.*|deny = ${MAX_DENY}|" "$FAILLOCK_CONF"
else
    echo "deny = ${MAX_DENY}" >> "$FAILLOCK_CONF"
fi

# Remove deny from pam files (should be in faillock.conf only)
while IFS= read -r -d $'\0' file; do
    sed -i -E 's/(pam_faillock\.so[^#\n]*)\bdeny=[0-9]+\b/\1/g' "$file"
done < <(find /usr/share/pam-configs -type f -print0 2>/dev/null)

# Validate
flag=1
if ! grep -Pi -- "^\h*deny\h*=\h*([1-${MAX_DENY}])\b" "$FAILLOCK_CONF" 2>/dev/null | grep -q .; then
    flag=0
fi

if (( flag )); then
    echo -e "${GREEN}SUCCESS${RESET}"
else
    echo -e "${RED}FAILED${RESET}"
    exit 1
fi

exit 0
