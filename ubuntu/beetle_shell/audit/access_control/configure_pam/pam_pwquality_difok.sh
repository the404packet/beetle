#!/usr/bin/env bash

NAME="ensure password number of changed characters is configured"
SEVERITY='basic'

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

[ -f "$SSH_RAM_STORE" ] && source "$SSH_RAM_STORE"

MIN_DIFOK="${PAM_PWQUALITY_DIFOK_MIN:-2}"

flag=1

# difok must be >= MIN in pwquality config
if ! grep -Psi -- "^\h*difok\h*=\h*([${MIN_DIFOK}-9]|[1-9][0-9]+)\b" \
   /etc/security/pwquality.conf /etc/security/pwquality.conf.d/*.conf 2>/dev/null | grep -q .; then
    flag=0
fi

# difok must NOT be overridden to 0 or 1 in pam files
if grep -Psi -- "^\h*password\h+(requisite|required|sufficient)\h+pam_pwquality\.so\h+([^#\n\r]+\h+)?difok\h*=\h*([0-1])\b" \
   /etc/pam.d/common-password 2>/dev/null | grep -q .; then
    flag=0
fi

if (( flag )); then
    echo -e "${GREEN}HARDENED${RESET}"
else
    echo -e "${RED}NOT HARDENED${RESET}"
fi

exit 0
