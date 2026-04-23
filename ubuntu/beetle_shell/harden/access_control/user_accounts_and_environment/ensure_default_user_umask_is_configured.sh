#!/usr/bin/env bash

NAME="ensure default user umask is configured"
SEVERITY='basic'

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

[ -f "$SSH_RAM_STORE" ] && source "$SSH_RAM_STORE"

UMASK_VAL="${UE_umask_value:-027}"
TARGET_FILE="${UE_umask_profile_d_file:-/etc/profile.d/50-systemwide_umask.sh}"

# Permissive umask regex
bad_pattern='^\h*umask\h+(([0-7][0-7][01][0-7]\b|[0-7][0-7][0-7][0-6]\b)|([0-7][01][0-7]\b|[0-7][0-7][0-6]\b)|(u=[rwx]{1,3},)?(((g=[rx]?[rx]?w[rx]?[rx]?\b)(,o=[rwx]{1,3})?)|((g=[wrx]{1,3},)?o=[wrx]{1,3}\b)))'

# Comment out permissive umask lines in all system-wide config files
for f in /etc/profile /etc/bashrc /etc/bash.bashrc; do
    [ -f "$f" ] || continue
    if grep -Psiq -- "$bad_pattern" "$f" 2>/dev/null; then
        sed -i -E "s|^(\h*umask\h+.*)$|# \1  # commented out by beetle|gI" "$f"
    fi
done

while IFS= read -r -d $'\0' f; do
    [ "$f" = "$TARGET_FILE" ] && continue
    if grep -Psiq -- "$bad_pattern" "$f" 2>/dev/null; then
        sed -i -E "s|^(\h*umask\h+.*)$|# \1  # commented out by beetle|gI" "$f"
    fi
done < <(find /etc/profile.d/ -type f -name '*.sh' -print0 2>/dev/null)

# Remove umask from pam_umask if set permissively
if [ -f /etc/pam.d/postlogin ]; then
    if grep -Psiq \
       '^\h*session\h+[^#\n\r]+\h+pam_umask\.so\h+([^#\n\r]+\h+)?umask=(([0-7][0-7][01][0-7]\b|[0-7][0-7][0-7][0-6]\b)|([0-7][01][0-7]\b))' \
       /etc/pam.d/postlogin 2>/dev/null; then
        sed -i -E 's|(pam_umask\.so[^#\n]*)\bumask=[0-9]+\b|\1|g' /etc/pam.d/postlogin
    fi
fi

# Write the canonical umask configuration
mkdir -p "$(dirname "$TARGET_FILE")"
cat > "$TARGET_FILE" <<EOF
# Managed by beetle — CIS 5.4.3.3
umask ${UMASK_VAL}
EOF
chmod 644 "$TARGET_FILE"

# Validate — look for a correctly configured umask
good_pattern='^\h*umask\h+(0?[0-7][2-7]7|u(=[rwx]{0,3}),g=([rx]{0,2}),o=)(\h*#.*)?$'

l_output=""
l_output2=""

file_umask_chk() {
    local l_file="$1"
    if grep -Psiq -- "$good_pattern" "$l_file" 2>/dev/null; then
        l_output="$l_file"
    elif grep -Psiq -- "$bad_pattern" "$l_file" 2>/dev/null; then
        l_output2="$l_output2$l_file "
    fi
}

while IFS= read -r -d $'\0' l_file; do
    file_umask_chk "$l_file"
done < <(find /etc/profile.d/ -type f -name '*.sh' -print0 2>/dev/null)

[ -z "$l_output" ] && file_umask_chk "/etc/profile"
[ -z "$l_output" ] && file_umask_chk "/etc/bashrc"
[ -z "$l_output" ] && file_umask_chk "/etc/bash.bashrc"
[ -z "$l_output" ] && file_umask_chk "/etc/login.defs"
[ -z "$l_output" ] && file_umask_chk "/etc/default/login"

if [[ -n "$l_output" && -z "$l_output2" ]]; then
    echo -e "${GREEN}SUCCESS${RESET}"
    exit 0
else
    echo -e "${RED}FAILED${RESET}"
    exit 1
fi
