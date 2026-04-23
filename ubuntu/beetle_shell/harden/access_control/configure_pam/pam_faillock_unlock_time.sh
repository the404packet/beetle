#!/usr/bin/env bash

NAME='ensure password unlock time is configured'
SEVERITY='basic'

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

[ -f "$SSH_RAM_STORE" ] && source "$SSH_RAM_STORE"

UNLOCK_TIME="${PAM_FAILLOCK_UNLOCK_TIME_VALUE:-900}"
FAILLOCK_CONF="/etc/security/faillock.conf"

if grep -Piq '^\h*unlock_time\h*=' "$FAILLOCK_CONF" 2>/dev/null; then
    sed -i "s|^\h*unlock_time\h*=.*|unlock_time = ${UNLOCK_TIME}|" "$FAILLOCK_CONF"
else
    echo "unlock_time = ${UNLOCK_TIME}" >> "$FAILLOCK_CONF"
fi

# Remove unlock_time from pam files
while IFS= read -r -d $'\0' file; do
    sed -i -E 's/(pam_faillock\.so[^#\n]*)\bunlock_time=[0-9]+\b/\1/g' "$file"
done < <(find /usr/share/pam-configs -type f -print0 2>/dev/null)

# Validate
flag=1
if ! grep -Pi -- "^\h*unlock_time\h*=\h*(0|9[0-9][0-9]|[1-9][0-9]{3,})\b" \
   "$FAILLOCK_CONF" 2>/dev/null | grep -q .; then
    flag=0
fi

if (( flag )); then
    echo -e "${GREEN}SUCCESS${RESET}"
else
    echo -e "${RED}FAILED${RESET}"
    exit 1
fi

exit 0
