#!/usr/bin/env bash

NAME="ensure users must provide password for privilege escalation"
SEVERITY='moderate'

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

if ! is_package_installed "sudo" && ! is_package_installed "sudo-ldap"; then
    echo -e "${GREEN}SUCCESS${RESET}"
    exit 0
fi

while IFS= read -r -d $'\0' file; do
    sed -i 's/\bNOPASSWD\b[[:space:]]*://g' "$file"
done < <(find /etc/sudoers.d -type f ! -name '*~' ! -name '*.bak' -print0 2>/dev/null)
sed -i 's/\bNOPASSWD\b[[:space:]]*://g' /etc/sudoers 2>/dev/null

if grep -r "^[^#].*NOPASSWD" /etc/sudoers* 2>/dev/null | grep -q .; then
    echo -e "${RED}FAILED${RESET}"
    exit 1
fi

echo -e "${GREEN}SUCCESS${RESET}"
exit 0