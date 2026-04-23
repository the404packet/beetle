#!/usr/bin/env bash

NAME="ensure password history remember is configured"
SEVERITY='basic'

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

[ -f "$SSH_RAM_STORE" ] && source "$SSH_RAM_STORE"

REMEMBER_VALUE="${PAM_PWHISTORY_REMEMBER_MIN:-24}"

# Find and update the pam-configs profile containing pam_pwhistory
while IFS= read -r profile; do
    if grep -Piq '\bpam_pwhistory\.so\b' "$profile" 2>/dev/null; then
        # Update remember= if present, otherwise add it
        if grep -Piq '\bremember=[0-9]+\b' "$profile" 2>/dev/null; then
            sed -i -E "s/\bremember=[0-9]+\b/remember=${REMEMBER_VALUE}/" "$profile"
        else
            sed -i -E "s/(pam_pwhistory\.so)/\1 remember=${REMEMBER_VALUE}/" "$profile"
        fi
        pam-auth-update --enable "$(basename "$profile")" 2>/dev/null
    fi
done < <(find /usr/share/pam-configs -type f 2>/dev/null)

# Validate
if grep -Psi -- "^\h*password\h+[^#\n\r]+\h+pam_pwhistory\.so\h+([^#\n\r]+\h+)?remember=${REMEMBER_VALUE}\b" \
   /etc/pam.d/common-password 2>/dev/null | grep -q .; then
    echo -e "${GREEN}SUCCESS${RESET}"
else
    echo -e "${RED}FAILED${RESET}"
    exit 1
fi

exit 0
