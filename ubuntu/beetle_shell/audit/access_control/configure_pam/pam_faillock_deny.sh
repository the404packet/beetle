#!/usr/bin/env bash

NAME='ensure password failed attempts lockout is configured'
SEVERITY='basic'

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

[ -f "$SSH_RAM_STORE" ] && source "$SSH_RAM_STORE"

MAX_DENY="${PAM_FAILLOCK_DENY_MAX:-5}"

flag=1

# deny must be set in faillock.conf and be 1-MAX_DENY
if ! grep -Pi -- "^\h*deny\h*=\h*([1-${MAX_DENY}])\b" /etc/security/faillock.conf 2>/dev/null | grep -q .; then
    flag=0
fi

# deny must NOT be set to 0 or >MAX_DENY in pam files
if grep -Pi -- "^\h*auth\h+(requisite|required|sufficient)\h+pam_faillock\.so\h+([^#\n\r]+\h+)?deny\h*=\h*(0|[6-9]|[1-9][0-9]+)\b" \
   /etc/pam.d/common-auth 2>/dev/null | grep -q .; then
    flag=0
fi

if (( flag )); then
    echo -e "${GREEN}HARDENED${RESET}"
else
    echo -e "${RED}NOT HARDENED${RESET}"
fi

exit 0
