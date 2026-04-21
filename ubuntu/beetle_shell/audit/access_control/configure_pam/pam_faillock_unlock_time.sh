#!/usr/bin/env bash

NAME='ensure password unlock time is configured'
SEVERITY='basic'

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

[ -f "$SSH_RAM_STORE" ] && source "$SSH_RAM_STORE"

MIN_UNLOCK="${PAM_FAILLOCK_UNLOCK_TIME_MIN:-900}"

flag=1

# unlock_time must be 0 (never) or >= MIN_UNLOCK in faillock.conf
if ! grep -Pi -- "^\h*unlock_time\h*=\h*(0|9[0-9][0-9]|[1-9][0-9]{3,})\b" \
   /etc/security/faillock.conf 2>/dev/null | grep -q .; then
    flag=0
fi

# unlock_time must NOT be set to 1-899 in pam files
if grep -Pi -- "^\h*auth\h+(requisite|required|sufficient)\h+pam_faillock\.so\h+([^#\n\r]+\h+)?unlock_time\h*=\h*([1-9]|[1-9][0-9]|[1-8][0-9][0-9])\b" \
   /etc/pam.d/common-auth 2>/dev/null | grep -q .; then
    flag=0
fi

if (( flag )); then
    echo -e "${GREEN}HARDENED${RESET}"
else
    echo -e "${RED}NOT HARDENED${RESET}"
fi

exit 0
