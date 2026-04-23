#!/usr/bin/env bash

NAME="ensure password failed attempts lockout includes root account"
SEVERITY='moderate'

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

[ -f "$SSH_RAM_STORE" ] && source "$SSH_RAM_STORE"

ROOT_UNLOCK_TIME="${PAM_FAILLOCK_ROOT_UNLOCK_TIME_VALUE:-60}"
FAILLOCK_CONF="/etc/security/faillock.conf"

# Add even_deny_root if not present
if ! grep -Piq '^\h*even_deny_root\b' "$FAILLOCK_CONF" 2>/dev/null; then
    echo "even_deny_root" >> "$FAILLOCK_CONF"
fi

# Set root_unlock_time if present and too low — or add it
if grep -Piq '^\h*root_unlock_time\h*=' "$FAILLOCK_CONF" 2>/dev/null; then
    sed -i "s|^\h*root_unlock_time\h*=.*|root_unlock_time = ${ROOT_UNLOCK_TIME}|" "$FAILLOCK_CONF"
else
    echo "root_unlock_time = ${ROOT_UNLOCK_TIME}" >> "$FAILLOCK_CONF"
fi

# Remove even_deny_root and root_unlock_time from pam-configs
while IFS= read -r -d $'\0' file; do
    sed -i -E 's/(pam_faillock\.so[^#\n]*)\beven_deny_root\b/\1/g' "$file"
    sed -i -E 's/(pam_faillock\.so[^#\n]*)\broot_unlock_time=[0-9]+\b/\1/g' "$file"
done < <(find /usr/share/pam-configs -type f -print0 2>/dev/null)

# Validate
flag=1
if ! grep -Piq '^\h*even_deny_root\b' "$FAILLOCK_CONF" 2>/dev/null; then
    flag=0
fi

if (( flag )); then
    echo -e "${GREEN}SUCCESS${RESET}"
else
    echo -e "${RED}FAILED${RESET}"
    exit 1
fi

exit 0
