#!/usr/bin/env bash

NAME="ensure GPG keys are configured"

GREEN="\e[32m"
RED="\e[31m"
CYAN="\e[36m"
RESET="\e[0m"

[ -f "$INITIAL_SETUP_RAM_STORE" ] && source "$INITIAL_SETUP_RAM_STORE"

key_count="$PM_gpg_key_count"
failed=false

for ((i=0; i<key_count; i++)); do
    keyid_var="PM_gpg_key_${i}_keyid"
    keyid="${!keyid_var}"

    if ! apt-key list 2>/dev/null | grep -qi "$keyid"; then
        failed=true
        break
    fi
done

$failed && echo -e "${RED}NOT HARDENED${RESET}" || echo -e "${GREEN}HARDENED${RESET}"
exit 0