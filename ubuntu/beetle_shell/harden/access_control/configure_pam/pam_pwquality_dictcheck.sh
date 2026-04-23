#!/usr/bin/env bash

NAME='ensure password dictionary check is enabled'
SEVERITY='basic'

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

# Comment out any dictcheck = 0 in config files
sed -ri 's/^\s*dictcheck\s*=\s*0/# &/' /etc/security/pwquality.conf 2>/dev/null
find /etc/security/pwquality.conf.d -name "*.conf" 2>/dev/null | \
    xargs -r sed -ri 's/^\s*dictcheck\s*=\s*0/# &/'

# Remove dictcheck from pam-configs
while IFS= read -r -d $'\0' file; do
    sed -i -E 's/(pam_pwquality\.so[^#\n]*)\bdictcheck=[0-9]+\b/\1/g' "$file"
done < <(find /usr/share/pam-configs -type f -print0 2>/dev/null)

# Validate — neither location should have dictcheck=0
flag=1
if grep -Psi -- "^\h*dictcheck\h*=\h*0\b" \
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
