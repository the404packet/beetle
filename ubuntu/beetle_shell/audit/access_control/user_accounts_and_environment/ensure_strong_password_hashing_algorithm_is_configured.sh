#!/usr/bin/env bash

NAME='ensure strong password hashing algorithm is configured'
SEVERITY='basic'

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

[ -f "$SSH_RAM_STORE" ] && source "$SSH_RAM_STORE"

# LD_encrypt_method_allowed is pipe-separated, e.g. "SHA512|YESCRYPT"
ALLOWED_RAW="${LD_encrypt_method_allowed:-SHA512|YESCRYPT}"
LOGIN_DEFS="${LD_file:-/etc/login.defs}"

flag=1

val=$(grep -Pi -- '^\h*ENCRYPT_METHOD\h+\S+\b' "$LOGIN_DEFS" 2>/dev/null \
    | awk '{print toupper($2)}' | head -1)

if [[ -z "$val" ]]; then
    flag=0
else
    matched=0
    IFS='|' read -ra allowed_arr <<< "$ALLOWED_RAW"
    for algo in "${allowed_arr[@]}"; do
        [[ "${val}" == "${algo^^}" ]] && matched=1
    done
    (( matched == 0 )) && flag=0
fi

if (( flag )); then
    echo -e "${GREEN}HARDENED${RESET}"
else
    echo -e "${RED}NOT HARDENED${RESET}"
fi

exit 0
