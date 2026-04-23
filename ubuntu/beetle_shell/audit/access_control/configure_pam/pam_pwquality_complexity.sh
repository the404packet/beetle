#!/usr/bin/env bash

NAME="ensure password complexity is configured"
SEVERITY='basic'

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

flag=1

# At least one complexity option must be set and none > 0
if ! grep -Psi -- "^\h*(minclass|[dulo]credit)\b" \
   /etc/security/pwquality.conf /etc/security/pwquality.conf.d/*.conf 2>/dev/null | grep -q .; then
    flag=0
fi

# dcredit/ucredit/lcredit/ocredit must not be > 0 in config files
if grep -Psi -- "^\h*[dulo]credit\h*=\h*[1-9]" \
   /etc/security/pwquality.conf /etc/security/pwquality.conf.d/*.conf 2>/dev/null | grep -q .; then
    flag=0
fi

# Must not be overridden in pam files
if grep -Psi -- "^\h*password\h+(requisite|required|sufficient)\h+pam_pwquality\.so\h+([^#\n\r]+\h+)?(minclass=\d*|[dulo]credit=-?\d*)\b" \
   /etc/pam.d/common-password 2>/dev/null | grep -q .; then
    flag=0
fi

if (( flag )); then
    echo -e "${GREEN}HARDENED${RESET}"
else
    echo -e "${RED}NOT HARDENED${RESET}"
fi

exit 0
