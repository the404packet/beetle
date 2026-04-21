#!/usr/bin/env bash

NAME='ensure pam_pwhistory module is enabled'
SEVERITY='basic'

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

PROFILE=$(grep -Pl -- '\bpam_pwhistory\.so\b' /usr/share/pam-configs/* 2>/dev/null | head -1)

if [ -z "$PROFILE" ]; then
    cat > /usr/share/pam-configs/pwhistory <<'EOF'
Name: pwhistory password history checking
Default: yes
Priority: 1024
Password-Type: Primary
Password:
	requisite pam_pwhistory.so remember=24 enforce_for_root try_first_pass use_authtok
EOF
    PROFILE="pwhistory"
else
    PROFILE=$(basename "$PROFILE")
fi

pam-auth-update --enable "$PROFILE" 2>/dev/null

if grep -P -- '\bpam_pwhistory\.so\b' /etc/pam.d/common-password 2>/dev/null | grep -q .; then
    echo -e "${GREEN}SUCCESS${RESET}"
else
    echo -e "${RED}FAILED${RESET}"
    exit 1
fi

exit 0
