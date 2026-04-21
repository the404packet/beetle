#!/usr/bin/env bash

NAME="ensure dccp kernel module is not available"

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

[ -f "$NETWORK_RAM_STORE" ] && source "$NETWORK_RAM_STORE"

mod_name="dccp"
mod_type="net"
mod_path="$(readlink -f /lib/modules/**/kernel/$mod_type 2>/dev/null | sort -u)"

if [ -z "$mod_path" ]; then
    echo -e "${GREEN}SUCCESS${RESET}"
    exit 0
fi

for mod_base in $mod_path; do
    if [ -d "$mod_base/${mod_name}" ] && [ -n "$(ls -A "$mod_base/${mod_name}" 2>/dev/null)" ]; then
        a_showconfig=()
        while IFS= read -r l_showconfig; do
            a_showconfig+=("$l_showconfig")
        done < <(modprobe --showconfig | grep -P -- "\b(install|blacklist)\h+${mod_name}\b")

        if lsmod | grep -q "$mod_name" 2>/dev/null; then
            modprobe -r "$mod_name" 2>/dev/null
            rmmod "$mod_name" 2>/dev/null
        fi
        if ! grep -Pq -- "\binstall\h+${mod_name}\h+(\/usr)?\/bin\/(true|false)\b" <<< "${a_showconfig[*]}"; then
            printf '%s\n' "install $mod_name $(readlink -f /bin/false)" >> /etc/modprobe.d/"$mod_name".conf
        fi
        if ! grep -Pq -- "\bblacklist\h+${mod_name}\b" <<< "${a_showconfig[*]}"; then
            printf '%s\n' "blacklist $mod_name" >> /etc/modprobe.d/"$mod_name".conf
        fi
    fi
done

failed=false
for mod_base in $mod_path; do
    if [ -d "$mod_base/${mod_name}" ] && [ -n "$(ls -A "$mod_base/${mod_name}" 2>/dev/null)" ]; then
        if lsmod | grep -q "$mod_name" 2>/dev/null; then failed=true; break; fi
        a_showconfig=()
        while IFS= read -r l_showconfig; do
            a_showconfig+=("$l_showconfig")
        done < <(modprobe --showconfig | grep -P -- "\b(install|blacklist)\h+${mod_name}\b")
        if ! grep -Pq -- "\binstall\h+${mod_name}\h+(\/usr)?\/bin\/(true|false)\b" <<< "${a_showconfig[*]}"; then
            failed=true; break
        fi
        if ! grep -Pq -- "\bblacklist\h+${mod_name}\b" <<< "${a_showconfig[*]}"; then
            failed=true; break
        fi
    fi
done

$failed && { echo -e "${RED}FAILED${RESET}"; exit 1; } || echo -e "${GREEN}SUCCESS${RESET}"
exit 0