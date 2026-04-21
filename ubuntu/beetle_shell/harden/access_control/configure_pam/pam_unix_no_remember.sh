#!/usr/bin/env bash

NAME='ensure pam_unix does not include remember'
SEVERITY='basic'

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

# Remove remember=N from pam-configs pam_unix lines
while IFS= read -r -d $'\0' file; do
    if grep -Piq '\bpam_unix\.so\b' "$file" 2>/dev/null; then
        sed -i -E 's/(pam_unix\.so[^#\n]*)\bremember=[0-9]+\b/\1/g' "$file"
        pam-auth-update --enable "$(basename "$file")" 2>/dev/null
    fi
done < <(find /usr/share/pam-configs -type f -print0 2>/dev/null)

# Validate
flag=1
for context in password auth account session session-noninteractive; do
    file="/etc/pam.d/common-${context}"
    [ -f "$file" ] || continue
    if grep -PH -- '^\h*[^#\n\r]+\h+pam_unix\.so\b' "$file" 2>/dev/null | grep -Pq '\bremember=\d+\b'; then
        flag=0
        break
    fi
done

if (( flag )); then
    echo -e "${GREEN}SUCCESS${RESET}"
else
    echo -e "${RED}FAILED${RESET}"
    exit 1
fi

exit 0
