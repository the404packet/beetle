#!/usr/bin/env bash

NAME="ensure GPG keys are configured"

GREEN="\e[32m"
RED="\e[31m"
CYAN="\e[36m"
RESET="\e[0m"

[ -f "$INITIAL_SETUP_RAM_STORE" ] && source "$INITIAL_SETUP_RAM_STORE"

echo ""
echo -e "${CYAN}  Currently configured GPG keys:${RESET}"

gpg_dir_count="$PM_gpg_dir_count"
gpg_ext_count="$PM_gpg_ext_count"

for ((d=0; d<gpg_dir_count; d++)); do
    dir_var="PM_gpg_dir_${d}"
    dir="${!dir_var}"
    for ((e=0; e<gpg_ext_count; e++)); do
        ext_var="PM_gpg_ext_${e}"
        ext="${!ext_var}"
        for file in "${dir}"/*.${ext}; do
            [ -f "$file" ] && echo "    $file"
        done
    done
done

echo ""
echo -e "  Beetle recommends the following GPG keys:"

key_count="$PM_gpg_key_count"
for ((i=0; i<key_count; i++)); do
    name_var="PM_gpg_key_${i}_name"
    echo "    ${!name_var}"
done

echo ""
echo -e "  Press ${GREEN}ENTER${RESET} to apply beetle recommended GPG keys"
echo -e "  Type   ${RED}no${RESET}   to keep current keys"
read -r -p "  Choice: " response

if [[ "$response" == "no" ]]; then
    echo -e "${GREEN}SUCCESS${RESET}"
    exit 0
fi

failed=false
for ((i=0; i<key_count; i++)); do
    keyid_var="PM_gpg_key_${i}_keyid"
    keyserver_var="PM_gpg_key_${i}_keyserver"
    keyid="${!keyid_var}"
    keyserver="${!keyserver_var}"

    apt-key adv --keyserver "$keyserver" --recv-keys "$keyid" &>/dev/null
    if ! apt-key list 2>/dev/null | grep -qi "$keyid"; then
        failed=true
        break
    fi
done

if $failed; then
    echo -e "${RED}FAILED${RESET}"
    exit 1
fi

echo -e "${GREEN}SUCCESS${RESET}"
exit 0