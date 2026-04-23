#!/usr/bin/env bash

NAME='ensure sudo commands use pty'
SEVERITY='basic'

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

if ! is_package_installed "sudo" && ! is_package_installed "sudo-ldap"; then
    echo -e "${GREEN}SUCCESS${RESET}"
    exit 0
fi

flag=1

# Remove any !use_pty occurrences
while IFS= read -r -d $'\0' file; do
    sed -i 's/,\s*!use_pty//g; s/!use_pty,\s*//g; s/^\s*Defaults\s\+!use_pty\s*$//g' "$file"
done < <(find /etc/sudoers.d -type f ! -name '*~' ! -name '*.bak' -print0 2>/dev/null)
sed -i 's/,\s*!use_pty//g; s/!use_pty,\s*//g; s/^\s*Defaults\s\+!use_pty\s*$//g' /etc/sudoers 2>/dev/null

# Add use_pty if not present
if ! grep -rPi -- '^\h*Defaults\h+([^#\n\r]+,\h*)?use_pty\b' /etc/sudoers* 2>/dev/null | grep -q .; then
    echo "Defaults use_pty" >> /etc/sudoers
fi

# Validate
if ! grep -rPi -- '^\h*Defaults\h+([^#\n\r]+,\h*)?use_pty\b' /etc/sudoers* 2>/dev/null | grep -q .; then
    flag=0
fi
if grep -rPi -- '^\h*Defaults\h+([^#\n\r]+,\h*)?!use_pty\b' /etc/sudoers* 2>/dev/null | grep -q .; then
    flag=0
fi

if (( flag )); then
    echo -e "${GREEN}SUCCESS${RESET}"
else
    echo -e "${RED}FAILED${RESET}"
    exit 1
fi

exit 0