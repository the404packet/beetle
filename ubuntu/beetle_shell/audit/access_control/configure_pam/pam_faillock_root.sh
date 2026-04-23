#!/usr/bin/env bash

NAME="ensure password failed attempts lockout includes root account"
SEVERITY='moderate'

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

[ -f "$SSH_RAM_STORE" ] && source "$SSH_RAM_STORE"

MIN_ROOT_UNLOCK="${PAM_FAILLOCK_ROOT_UNLOCK_TIME_MIN:-60}"

flag=1

# even_deny_root or root_unlock_time must be set
if ! grep -Pi -- "^\h*(even_deny_root|root_unlock_time\h*=\h*\d+)\b" \
   /etc/security/faillock.conf 2>/dev/null | grep -q .; then
    flag=0
fi

# if root_unlock_time is set it must be >= MIN_ROOT_UNLOCK
if grep -Pi -- "^\h*root_unlock_time\h*=\h*([1-9]|[1-5][0-9])\b" \
   /etc/security/faillock.conf 2>/dev/null | grep -q .; then
    flag=0
fi

# root_unlock_time must not be set < MIN in pam files
if grep -Pi -- "^\h*auth\h+([^#\n\r]+\h+)pam_faillock\.so\h+([^#\n\r]+\h+)?root_unlock_time\h*=\h*([1-9]|[1-5][0-9])\b" \
   /etc/pam.d/common-auth 2>/dev/null | grep -q .; then
    flag=0
fi

if (( flag )); then
    echo -e "${GREEN}HARDENED${RESET}"
else
    echo -e "${RED}NOT HARDENED${RESET}"
fi

exit 0
