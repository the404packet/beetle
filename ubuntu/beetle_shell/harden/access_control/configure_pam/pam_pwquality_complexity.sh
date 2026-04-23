#!/usr/bin/env bash

NAME="ensure password complexity is configured"
SEVERITY='basic'

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

[ -f "$SSH_RAM_STORE" ] && source "$SSH_RAM_STORE"

MINCLASS="${PAM_PWQUALITY_MINCLASS:-3}"
CONF_DIR="/etc/security/pwquality.conf.d"
CONF_FILE="${CONF_DIR}/50-pwcomplexity.conf"

[ ! -d "$CONF_DIR" ] && mkdir -p "$CONF_DIR"

# Comment out existing complexity settings in main config
sed -ri 's/^\s*minclass\s*=/# &/' /etc/security/pwquality.conf 2>/dev/null
sed -ri 's/^\s*[dulo]credit\s*=/# &/' /etc/security/pwquality.conf 2>/dev/null

# Write drop-in
printf '%s\n' "minclass = ${MINCLASS}" > "$CONF_FILE"

# Remove from pam-configs
while IFS= read -r -d $'\0' file; do
    sed -i -E 's/(pam_pwquality\.so[^#\n]*)\bminclass=[0-9]+\b/\1/g' "$file"
    sed -i -E 's/(pam_pwquality\.so[^#\n]*)\b[dulo]credit=-?[0-9]+\b/\1/g' "$file"
done < <(find /usr/share/pam-configs -type f -print0 2>/dev/null)

# Validate
if grep -Psi -- "^\h*(minclass|[dulo]credit)\b" \
   /etc/security/pwquality.conf /etc/security/pwquality.conf.d/*.conf 2>/dev/null | grep -q .; then
    echo -e "${GREEN}SUCCESS${RESET}"
else
    echo -e "${RED}FAILED${RESET}"
    exit 1
fi

exit 0
