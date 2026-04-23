#!/usr/bin/env bash

NAME="ensure password same consecutive characters is configured"
SEVERITY='basic'

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

[ -f "$SSH_RAM_STORE" ] && source "$SSH_RAM_STORE"

MAX_REPEAT="${PAM_PWQUALITY_MAXREPEAT_MAX:-3}"

flag=1

# maxrepeat must be 1-MAX_REPEAT (not 0) in config
if ! grep -Psi -- "^\h*maxrepeat\h*=\h*[1-${MAX_REPEAT}]\b" \
   /etc/security/pwquality.conf /etc/security/pwquality.conf.d/*.conf 2>/dev/null | grep -q .; then
    flag=0
fi

# Must not be overridden to 0 or >MAX_REPEAT in pam files
if grep -Psi -- "^\h*password\h+(requisite|required|sufficient)\h+pam_pwquality\.so\h+([^#\n\r]+\h+)?maxrepeat\h*=\h*(0|[4-9]|[1-9][0-9]+)\b" \
   /etc/pam.d/common-password 2>/dev/null | grep -q .; then
    flag=0
fi

if (( flag )); then
    echo -e "${GREEN}HARDENED${RESET}"
else
    echo -e "${RED}NOT HARDENED${RESET}"
fi

exit 0
