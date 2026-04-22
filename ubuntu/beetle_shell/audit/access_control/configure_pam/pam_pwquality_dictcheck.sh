#!/usr/bin/env bash

NAME="ensure password dictionary check is enabled"
SEVERITY='basic'

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

flag=1

# dictcheck must NOT be set to 0 in config files
if grep -Psi -- "^\h*dictcheck\h*=\h*0\b" \
   /etc/security/pwquality.conf /etc/security/pwquality.conf.d/*.conf 2>/dev/null | grep -q .; then
    flag=0
fi

# dictcheck must NOT be set to 0 as a pam argument
if grep -Psi -- "^\h*password\h+(requisite|required|sufficient)\h+pam_pwquality\.so\h+([^#\n\r]+\h+)?dictcheck\h*=\h*0\b" \
   /etc/pam.d/common-password 2>/dev/null | grep -q .; then
    flag=0
fi

if (( flag )); then
    echo -e "${GREEN}HARDENED${RESET}"
else
    echo -e "${RED}NOT HARDENED${RESET}"
fi

exit 0
