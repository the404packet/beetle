#!/usr/bin/env bash

NAME='ensure password quality checking is enforced'
SEVERITY='basic'

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

# Comment out enforcing = 0 in config files
sed -ri 's/^\s*enforcing\s*=\s*0/# &/' /etc/security/pwquality.conf 2>/dev/null
find /etc/security/pwquality.conf.d -name "*.conf" 2>/dev/null | \
    xargs -r sed -ri 's/^\s*enforcing\s*=\s*0/# &/'

# Remove enforcing=0 from pam-configs
while IFS= read -r -d $'\0' file; do
    sed -i -E 's/(pam_pwquality\.so[^#\n]*)\benforcing=0\b/\1/g' "$file"
done < <(find /usr/share/pam-configs -type f -print0 2>/dev/null)

# Validate
flag=1
if grep -PHsi -- "^\h*enforcing\h*=\h*0\b" \
   /etc/security/pwquality.conf /etc/security/pwquality.conf.d/*.conf 2>/dev/null | grep -q .; then
    flag=0
fi

if (( flag )); then
    echo -e "${GREEN}SUCCESS${RESET}"
else
    echo -e "${RED}FAILED${RESET}"
    exit 1
fi

exit 0
