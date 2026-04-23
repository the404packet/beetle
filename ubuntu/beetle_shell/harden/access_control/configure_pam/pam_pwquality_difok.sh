#!/usr/bin/env bash

NAME="ensure password number of changed characters is configured"
SEVERITY='basic'

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

[ -f "$SSH_RAM_STORE" ] && source "$SSH_RAM_STORE"

DIFOK_VALUE="${PAM_PWQUALITY_DIFOK_MIN:-2}"
CONF_DIR="/etc/security/pwquality.conf.d"
CONF_FILE="${CONF_DIR}/50-pwdifok.conf"

[ ! -d "$CONF_DIR" ] && mkdir -p "$CONF_DIR"

# Comment out any existing difok in main config
sed -ri 's/^\s*difok\s*=/# &/' /etc/security/pwquality.conf 2>/dev/null

# Write to drop-in
printf '\n%s\n' "difok = ${DIFOK_VALUE}" > "$CONF_FILE"

# Remove difok from pam-configs
while IFS= read -r -d $'\0' file; do
    sed -i -E 's/(pam_pwquality\.so[^#\n]*)\bdifok=[0-9]+\b/\1/g' "$file"
done < <(find /usr/share/pam-configs -type f -print0 2>/dev/null)

# Validate
if grep -Psi -- "^\h*difok\h*=\h*([${DIFOK_VALUE}-9]|[1-9][0-9]+)\b" \
   /etc/security/pwquality.conf /etc/security/pwquality.conf.d/*.conf 2>/dev/null | grep -q .; then
    echo -e "${GREEN}SUCCESS${RESET}"
else
    echo -e "${RED}FAILED${RESET}"
    exit 1
fi

exit 0
