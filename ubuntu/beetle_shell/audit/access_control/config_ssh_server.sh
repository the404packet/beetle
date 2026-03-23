#!/usr/bin/env bash

NAME='/etc/ssh/sshd_config file permission'
SEVERITY='basic'


perm_mask=0177
flag=1

check_file(){
    local file=$1
    local mode owner group
    read -r mode owner group < <(stat -Lc '%#a %U %G' "$file")
    if (( $mode & perm_mask )) || [[ $owner != "root" || $group != "root" ]]; then
        return 1 #file is not compliant
    fi
    return 0 #file is compliant
}


#sshd_config file
if [[ -f /etc/ssh/sshd_config ]]; then 
    if ! check_file /etc/ssh/sshd_config; then
        flag=0
    fi
fi

#check if conf exist in sshd_config.d/
if (( flag )) && [[ -d /etc/ssh/sshd_config.d ]]; then
    while IFS= read -r -d $'\0' file; do
        if !check_file "$file"; then
            flag=0
            break
        fi
    done < <(find /etc/ssh/sshd_config.d -type f -name "*.conf" -print0)
fi

if (( flag )); then
    echo -e "${GREEN}HARDENED${RESET}"
else
    echo -e "${RED}NOT HARDENED${RESET}"
fi

exit 0