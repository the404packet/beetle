#!/usr/bin/env bash

NAME="ensure root user umask is configured"
SEVERITY='basic'

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

[ -f "$SSH_RAM_STORE" ] && source "$SSH_RAM_STORE"

flag=1

# Read root umask config files from RAM store
count="${UE_root_umask_file_count:-2}"
declare -a root_umask_files
for (( i=0; i<count; i++ )); do
    var="UE_root_umask_file_${i}"
    root_umask_files+=("${!var}")
done
# Fallback if RAM store not loaded
(( ${#root_umask_files[@]} == 0 )) && root_umask_files=("/root/.bash_profile" "/root/.bashrc")

# Check that none of the root shell files contain a permissive umask
# A permissive umask pattern (less restrictive than 027)
permissive_pattern='^\h*umask\h+(([0-7][0-7][01][0-7]\b|[0-7][0-7][0-7][0-6]\b)|([0-7][01][0-7]\b|[0-7][0-7][0-6]\b)|(u=[rwx]{1,3},)?(((g=[rx]?[rx]?w[rx]?[rx]?\b)(,o=[rwx]{1,3})?)|((g=[wrx]{1,3},)?o=[wrx]{1,3}\b)))'

for f in "${root_umask_files[@]}"; do
    [ -f "$f" ] || continue
    if grep -Psi -- "$permissive_pattern" "$f" >/dev/null 2>&1; then
        flag=0
    fi
done

if (( flag )); then
    echo -e "${GREEN}HARDENED${RESET}"
else
    echo -e "${RED}NOT HARDENED${RESET}"
fi

exit 0
