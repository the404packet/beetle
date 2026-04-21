#!/usr/bin/env bash

NAME='ensure pam_unix does not include nullok'
SEVERITY='basic'

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

# Remove nullok from pam-configs
while IFS= read -r -d $'\0' file; do
    if grep -Piq '\bpam_unix\.so\b' "$file" 2>/dev/null; then
        sed -i -E 's/(pam_unix\.so[^#\n]*)\bnullok\b/\1/g' "$file"
        pam-auth-update --enable "$(basename "$file")" 2>/dev/null
    fi
done < <(find /usr/share/pam-configs -type f -print0 2>/dev/null)

# Validate — no nullok should remain
flag=1
for context in password auth account session session-noninteractive; do
    file="/etc/pam.d/common-${context}"
    [ -f "$file" ] || continue
    if grep -PH -- '^\h*[^#\n\r]+\h+pam_unix\.so\b' "$file" 2>/dev/null | grep -Pq '\bnullok\b'; then
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
