#!/usr/bin/env bash

NAME='ensure minimum password length is configured'
SEVERITY='basic'

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

[ -f "$SSH_RAM_STORE" ] && source "$SSH_RAM_STORE"

MINLEN_VALUE="${PAM_PWQUALITY_MINLEN_MIN:-14}"
CONF_DIR="/etc/security/pwquality.conf.d"
CONF_FILE="${CONF_DIR}/50-pwlength.conf"

[ ! -d "$CONF_DIR" ] && mkdir -p "$CONF_DIR"

sed -ri 's/^\s*minlen\s*=/# &/' /etc/security/pwquality.conf 2>/dev/null
printf '\n%s\n' "minlen = ${MINLEN_VALUE}" > "$CONF_FILE"

while IFS= read -r -d $'\0' file; do
    sed -i -E 's/(pam_pwquality\.so[^#\n]*)\bminlen=[0-9]+\b/\1/g' "$file"
done < <(find /usr/share/pam-configs -type f -print0 2>/dev/null)

if grep -Psi -- "^\h*minlen\h*=\h*(1[4-9]|[2-9][0-9]|[1-9][0-9]{2,})\b" \
   /etc/security/pwquality.conf /etc/security/pwquality.conf.d/*.conf 2>/dev/null | grep -q .; then
    echo -e "${GREEN}SUCCESS${RESET}"
else
    echo -e "${RED}FAILED${RESET}"
    exit 1
fi

exit 0
