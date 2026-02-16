#!/usr/bin/env bash

Name='/etc/ssh/sshd_config and sshd_config.d/*.conf access'
SEVERITY='basic'


#getting the required files
FILES=()

[[ -f /etc/ssh/sshd_config ]] && FILES+=(/etc/ssh/sshd_config)

if [[ -d /etc/ssh/sshd_config.d ]]; then
    while IFS= read -r -d $'\0' file; do
        FILES+=("$file")
    done < <(find /etc/ssh/sshd_config.d -type f -name "*.conf" -print0)
fi

