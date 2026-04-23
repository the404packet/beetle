#!/usr/bin/env bash

NAME='ensure pam_faillock module is enabled'
SEVERITY='basic'

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

flag=1

# Create faillock profile if missing
if [ ! -f /usr/share/pam-configs/faillock ]; then
    cat > /usr/share/pam-configs/faillock <<'EOF'
Name: Enable pam_faillock to deny access
Default: yes
Priority: 0
Auth-Type: Primary
Auth:
	[default=die] pam_faillock.so authfail
EOF
fi

# Create faillock_notify profile if missing
if [ ! -f /usr/share/pam-configs/faillock_notify ]; then
    cat > /usr/share/pam-configs/faillock_notify <<'EOF'
Name: Notify of failed login attempts and reset count upon success
Default: yes
Priority: 1024
Auth-Type: Primary
Auth:
	requisite pam_faillock.so preauth
Account-Type: Primary
Account:
	required pam_faillock.so
EOF
fi

pam-auth-update --enable faillock 2>/dev/null
pam-auth-update --enable faillock_notify 2>/dev/null

# Validate
if ! grep -P -- '\bpam_faillock\.so\b' /etc/pam.d/common-auth 2>/dev/null | grep -q 'preauth'; then
    flag=0
fi
if ! grep -P -- '\bpam_faillock\.so\b' /etc/pam.d/common-auth 2>/dev/null | grep -q 'authfail'; then
    flag=0
fi
if ! grep -P -- '\bpam_faillock\.so\b' /etc/pam.d/common-account 2>/dev/null | grep -q .; then
    flag=0
fi

if (( flag )); then
    echo -e "${GREEN}SUCCESS${RESET}"
else
    echo -e "${RED}FAILED${RESET}"
    exit 1
fi

exit 0
