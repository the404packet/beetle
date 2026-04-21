#!/usr/bin/env bash

NAME='ensure minimum password length is configured'
SEVERITY='basic'

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

[ -f "$SSH_RAM_STORE" ] && source "$SSH_RAM_STORE"

MIN_LEN="${PAM_PWQUALITY_MINLEN_MIN:-14}"

flag=1

# minlen must be >= MIN_LEN in pwquality config
if ! grep -Psi -- "^\h*minlen\h*=\h*(1[4-9]|[2-9][0-9]|[1-9][0-9]{2,})\b" \
   /etc/security/pwquality.conf /etc/security/pwquality.conf.d/*.conf 2>/dev/null | grep -q .; then
    flag=0
fi

# minlen must NOT be overridden to < MIN_LEN in pam files
if grep -Psi -- "^\h*password\h+(requisite|required|sufficient)\h+pam_pwquality\.so\h+([^#\n\r]+\h+)?minlen\h*=\h*([0-9]|1[0-3])\b" \
   /etc/pam.d/common-password 2>/dev/null | grep -q .; then
    flag=0
fi

if (( flag )); then
    echo -e "${GREEN}HARDENED${RESET}"
else
    echo -e "${RED}NOT HARDENED${RESET}"
fi

exit 0
