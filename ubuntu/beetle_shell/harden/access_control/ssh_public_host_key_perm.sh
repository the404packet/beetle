#!/usr/bin/env bash

NAME='ssh_public_host_key_permission'
SEVERITY='basic'

perm_mask=0133
flag=1

check_file(){
    local file=$1
    read -r mode owner group < <(stat -Lc '%#a %U %G' "$file")
    if (( $mode & perm_mask )) || [[ $owner != "root" || $group != "root" ]]; then
        return 1 #file is not compliant
    fi
    return 0 #file is compliant
}

if [[ -d /etc/ssh ]]; then
    while IFS= read -r -d $'\0' file; do
    if ssh-keygen -lf "$file" &>/dev/null && file "$file" | grep -Piq -- '\bopenssh\h+([^#\n\r]+\h+)?public\h+key\b'; then
        if ! check_file "$file"; then
            flag=0
            break
        fi
    fi
    done < <(find /etc/ssh -xdev -type f -print0)
fi


if (( flag )); then
    echo -e "${GREEN}HARDENED${RESET}"
else
    echo -e "${RED}NOT HARDENED${RESET}"
fi

exit 0