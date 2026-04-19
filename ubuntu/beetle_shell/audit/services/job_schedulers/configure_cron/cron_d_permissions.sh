#!/usr/bin/env bash

NAME="ensure permissions on /etc/cron.d are configured"

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

[ -f "$DPKG_RAM_STORE" ] && source "$DPKG_RAM_STORE"
[ -f "$SERVICES_RAM_STORE" ] && source "$SERVICES_RAM_STORE"

if ! is_package_installed "cron"; then
    echo -e "${GREEN}HARDENED${RESET}"
    exit 0
fi

file=""
mode=""
owner=""
group=""

dir_count="$JS_cron_dir_count"
for ((i=0; i<dir_count; i++)); do
    file_var="JS_cron_dir_${i}_file"
    if [[ "${!file_var}" == "/etc/cron.d" ]]; then
        file="${!file_var}"
        mode_var="JS_cron_dir_${i}_mode"
        owner_var="JS_cron_dir_${i}_owner"
        group_var="JS_cron_dir_${i}_group"
        mode="${!mode_var}"
        owner="${!owner_var}"
        group="${!group_var}"
        break
    fi
done

actual_mode=$(stat -Lc '%a' "$file" 2>/dev/null)
actual_owner=$(stat -Lc '%U' "$file" 2>/dev/null)
actual_group=$(stat -Lc '%G' "$file" 2>/dev/null)

if [[ "$actual_owner" != "$owner" ]] || \
   [[ "$actual_group" != "$group" ]] || \
   [[ "$actual_mode" -gt "$mode" ]] 2>/dev/null; then
    echo -e "${RED}NOT HARDENED${RESET}"
    exit 0
fi

echo -e "${GREEN}HARDENED${RESET}"
exit 0