#!/usr/bin/env bash

NAME='ensure pam_unix includes use_authtok'
SEVERITY='basic'

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

while IFS= read -r profile; do
    if grep -Piq '\bpam_unix\.so\b' "$profile" 2>/dev/null; then
        # Only add use_authtok to Password: section lines, not Password-Initial:
        awk '
        /^Password-Initial:/ { initial=1 }
        /^Password:/ { initial=0 }
        /^[A-Z]/ && !/^Password:/ { initial=0 }
        !initial && /pam_unix\.so/ && !/use_authtok/ {
            sub(/pam_unix\.so/, "pam_unix.so use_authtok")
        }
        { print }
        ' "$profile" > "${profile}.tmp" && mv "${profile}.tmp" "$profile"
        pam-auth-update --enable "$(basename "$profile")" 2>/dev/null
    fi
done < <(find /usr/share/pam-configs -type f 2>/dev/null)

if grep -PH -- '^\h*password\h+([^#\n\r]+)\h+pam_unix\.so\h+([^#\n\r]+\h+)?use_authtok\b' \
   /etc/pam.d/common-password 2>/dev/null | grep -q .; then
    echo -e "${GREEN}SUCCESS${RESET}"
else
    echo -e "${RED}FAILED${RESET}"
    exit 1
fi

exit 0
