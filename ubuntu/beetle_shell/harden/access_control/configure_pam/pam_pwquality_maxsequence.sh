#!/usr/bin/env bash

NAME='ensure password maximum sequential characters is configured'
SEVERITY='basic'

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

[ -f "$SSH_RAM_STORE" ] && source "$SSH_RAM_STORE"

MAXSEQ_VALUE="${PAM_PWQUALITY_MAXSEQUENCE_MAX:-3}"
CONF_DIR="/etc/security/pwquality.conf.d"
CONF_FILE="${CONF_DIR}/50-pwmaxsequence.conf"

[ ! -d "$CONF_DIR" ] && mkdir -p "$CONF_DIR"

sed -ri 's/^\s*maxsequence\s*=/# &/' /etc/security/pwquality.conf 2>/dev/null
printf '\n%s\n' "maxsequence = ${MAXSEQ_VALUE}" > "$CONF_FILE"

while IFS= read -r -d $'\0' file; do
    sed -i -E 's/(pam_pwquality\.so[^#\n]*)\bmaxsequence=[0-9]+\b/\1/g' "$file"
done < <(find /usr/share/pam-configs -type f -print0 2>/dev/null)

if grep -Psi -- "^\h*maxsequence\h*=\h*[1-${MAXSEQ_VALUE}]\b" \
   /etc/security/pwquality.conf /etc/security/pwquality.conf.d/*.conf 2>/dev/null | grep -q .; then
    echo -e "${GREEN}SUCCESS${RESET}"
else
    echo -e "${RED}FAILED${RESET}"
    exit 1
fi

exit 0
