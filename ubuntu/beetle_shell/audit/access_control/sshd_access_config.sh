#!/usr/bin/env bash

NAME='restrict ssh access using allow/deny list of user/grp'
SEVERITY='strict'

flag=1

if ! sshd -T 2>/dev/null |  grep -Piq '^\h*(allow|deny)(users|groups)\h+\H+'; then
    flag=0 # no list found
fi


# IF Match Block exists
if (( flag )) && \
   grep -Riq '^\s*Match\b' /etc/ssh/sshd_config /etc/ssh/sshd_config.d 2>/dev/null; then
    if ! sshd -T -C user="$USER" 2>/dev/null | \
         grep -Piq '^\h*(allow|deny)(users|groups)\h+\H+'; then
        flag=0
    fi
fi


if (( flag )); then
    echo -e "${GREEN}HARDENED${RESET}"
else
    echo -e "${RED}NOT HARDENED${RESET}"
fi

exit 0


