#!/usr/bin/env bash

NAME='ensure default user umask is configured'
SEVERITY='basic'

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

l_output=""
l_output2=""

# Pattern: umask is 027 or more restrictive
good_pattern='^\h*umask\h+(0?[0-7][2-7]7|u(=[rwx]{0,3}),g=([rx]{0,2}),o=)(\h*#.*)?$'
# Pattern: umask is set but permissive (less restrictive than 027)
bad_pattern='^\h*umask\h+(([0-7][0-7][01][0-7]\b|[0-7][0-7][0-7][0-6]\b)|([0-7][01][0-7]\b|[0-7][0-7][0-6]\b)|(u=[rwx]{1,3},)?(((g=[rx]?[rx]?w[rx]?[rx]?\b)(,o=[rwx]{1,3})?)|((g=[wrx]{1,3},)?o=[wrx]{1,3}\b)))'

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

# Check pam_umask in postlogin
if [ -z "$l_output" ] && [ -f /etc/pam.d/postlogin ]; then
    if grep -Psiq -- '^\h*session\h+[^#\n\r]+\h+pam_umask\.so\h+([^#\n\r]+\h+)?umask=(0?[0-7][2-7]7)\b' \
       /etc/pam.d/postlogin 2>/dev/null; then
        l_output="/etc/pam.d/postlogin"
    elif grep -Psiq \
       '^\h*session\h+[^#\n\r]+\h+pam_umask\.so\h+([^#\n\r]+\h+)?umask=(([0-7][0-7][01][0-7]\b|[0-7][0-7][0-7][0-6]\b)|([0-7][01][0-7]\b))' \
       /etc/pam.d/postlogin 2>/dev/null; then
        l_output2="$l_output2/etc/pam.d/postlogin "
    fi
fi

[ -z "$l_output" ] && file_umask_chk "/etc/login.defs"
[ -z "$l_output" ] && file_umask_chk "/etc/default/login"

if [[ -n "$l_output" && -z "$l_output2" ]]; then
    echo -e "${GREEN}HARDENED${RESET}"
else
    echo -e "${RED}NOT HARDENED${RESET}"
fi

exit 0
