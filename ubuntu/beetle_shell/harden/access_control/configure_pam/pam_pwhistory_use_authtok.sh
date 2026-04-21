#!/usr/bin/env bash

NAME='ensure pam_pwhistory includes use_authtok'
SEVERITY='basic'

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

while IFS= read -r profile; do
    if grep -Piq '\bpam_pwhistory\.so\b' "$profile" 2>/dev/null; then
        if ! grep -Piq '\buse_authtok\b' "$profile" 2>/dev/null; then
            sed -i -E 's/(pam_pwhistory\.so)/\1 use_authtok/' "$profile"
        fi
        pam-auth-update --enable "$(basename "$profile")" 2>/dev/null
    fi
done < <(find /usr/share/pam-configs -type f 2>/dev/null)

if grep -Psi -- "^\h*password\h+[^#\n\r]+\h+pam_pwhistory\.so\h+([^#\n\r]+\h+)?use_authtok\b" \
   /etc/pam.d/common-password 2>/dev/null | grep -q .; then
    echo -e "${GREEN}SUCCESS${RESET}"
else
    echo -e "${RED}FAILED${RESET}"
    exit 1
fi

exit 0
