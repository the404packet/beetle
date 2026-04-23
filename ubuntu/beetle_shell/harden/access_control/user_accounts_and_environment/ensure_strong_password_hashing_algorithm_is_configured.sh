#!/usr/bin/env bash

NAME="ensure strong password hashing algorithm is configured"
SEVERITY='basic'

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

[ -f "$SSH_RAM_STORE" ] && source "$SSH_RAM_STORE"

ALLOWED_RAW="${LD_encrypt_method_allowed:-SHA512|YESCRYPT}"
LOGIN_DEFS="${LD_file:-/etc/login.defs}"

# Pick the first listed algorithm as the target value
TARGET=$(echo "$ALLOWED_RAW" | cut -d'|' -f1)

# Update /etc/login.defs
if grep -Piq '^\h*ENCRYPT_METHOD\h+\S+\b' "$LOGIN_DEFS" 2>/dev/null; then
    sed -i "s|^\h*ENCRYPT_METHOD\h.*|ENCRYPT_METHOD ${TARGET}|" "$LOGIN_DEFS"
else
    echo "ENCRYPT_METHOD ${TARGET}" >> "$LOGIN_DEFS"
fi

# Validate
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
    echo -e "${GREEN}SUCCESS${RESET}"
    exit 0
else
    echo -e "${RED}FAILED${RESET}"
    exit 1
fi
