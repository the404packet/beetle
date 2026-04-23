#!/usr/bin/env bash

NAME='ensure re-authentication for privilege escalation is not disabled globally'
SEVERITY='basic'

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

if ! is_package_installed "sudo" && ! is_package_installed "sudo-ldap"; then
    echo -e "${GREEN}SUCCESS${RESET}"
    exit 0
fi

while IFS= read -r -d $'\0' file; do
    sed -i 's/,\s*!authenticate//g; s/!authenticate,\s*//g; s/^\s*Defaults\s\+!authenticate\s*$//g' "$file"
done < <(find /etc/sudoers.d -type f ! -name '*~' ! -name '*.bak' -print0 2>/dev/null)
sed -i 's/,\s*!authenticate//g; s/!authenticate,\s*//g; s/^\s*Defaults\s\+!authenticate\s*$//g' /etc/sudoers 2>/dev/null

if grep -r "^[^#].*\!authenticate" /etc/sudoers* 2>/dev/null | grep -q .; then
    echo -e "${RED}FAILED${RESET}"
    exit 1
fi

echo -e "${GREEN}SUCCESS${RESET}"
exit 0