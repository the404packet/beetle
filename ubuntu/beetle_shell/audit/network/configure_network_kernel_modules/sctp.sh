#!/usr/bin/env bash

NAME="ensure sctp kernel module is not available"

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

[ -f "$NETWORK_RAM_STORE" ] && source "$NETWORK_RAM_STORE"

mod_name="sctp"
mod_type="net"
mod_path="$(readlink -f /lib/modules/**/kernel/$mod_type 2>/dev/null | sort -u)"

if [ -z "$mod_path" ]; then
    echo -e "${GREEN}HARDENED${RESET}"
    exit 0
fi

failed=false
for mod_base in $mod_path; do
    if [ -d "$mod_base/${mod_name}" ] && [ -n "$(ls -A "$mod_base/${mod_name}" 2>/dev/null)" ]; then
        a_showconfig=()
        while IFS= read -r l_showconfig; do
            a_showconfig+=("$l_showconfig")
        done < <(modprobe --showconfig | grep -P -- "\b(install|blacklist)\h+${mod_name}\b")

        if lsmod | grep -q "$mod_name" 2>/dev/null; then
            failed=true; break
        fi
        if ! grep -Pq -- "\binstall\h+${mod_name}\h+(\/usr)?\/bin\/(true|false)\b" <<< "${a_showconfig[*]}"; then
            failed=true; break
        fi
        if ! grep -Pq -- "\bblacklist\h+${mod_name}\b" <<< "${a_showconfig[*]}"; then
            failed=true; break
        fi
    fi
done

$failed && echo -e "${RED}NOT HARDENED${RESET}" || echo -e "${GREEN}HARDENED${RESET}"
exit 0