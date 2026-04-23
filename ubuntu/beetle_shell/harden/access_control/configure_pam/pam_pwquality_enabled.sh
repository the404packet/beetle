#!/usr/bin/env bash

NAME="ensure pam_pwquality module is enabled"
SEVERITY='basic'

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

# Check if a profile already exists in pam-configs
PROFILE=$(grep -Pl -- '\bpam_pwquality\.so\b' /usr/share/pam-configs/* 2>/dev/null | head -1)

if [ -z "$PROFILE" ]; then
    # Create the profile
    cat > /usr/share/pam-configs/pwquality <<'EOF'
Name: Pwquality password strength checking
Default: yes
Priority: 1024
Conflicts: cracklib
Password-Type: Primary
Password:
	requisite pam_pwquality.so retry=3
EOF
    PROFILE="pwquality"
else
    PROFILE=$(basename "$PROFILE")
fi

pam-auth-update --enable "$PROFILE" 2>/dev/null

if grep -P -- '\bpam_pwquality\.so\b' /etc/pam.d/common-password 2>/dev/null | grep -q .; then
    echo -e "${GREEN}SUCCESS${RESET}"
else
    echo -e "${RED}FAILED${RESET}"
    exit 1
fi

exit 0
