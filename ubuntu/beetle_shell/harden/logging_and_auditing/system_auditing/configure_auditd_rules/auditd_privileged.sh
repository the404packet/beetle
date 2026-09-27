#!/usr/bin/env bash
NAME="ensure use of privileged commands are collected"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$LOGGING_RAM_STORE" ] && source "$LOGGING_RAM_STORE" || { echo -e "${RED}FAILED${RESET}"; exit 1; }

export DEBIAN_FRONTEND=noninteractive
if ! dpkg-query -W -f='${Status}' auditd 2>/dev/null | grep -q "install ok installed"; then
    apt-get install -y -q auditd audispd-plugins </dev/null >/dev/null 2>&1 || true
fi
[ -z "$AR_rules_dir" ] && { echo -e "${RED}FAILED${RESET} (rules dir not set)"; exit 1; }
mkdir -p "$AR_rules_dir"

idx=$(get_ar_group_index "privileged")
file_var="AR_${idx}_file"; rules_file="${AR_rules_dir}/${!file_var}"
uid_min=$(awk '/^\s*UID_MIN/{print $2}' /etc/login.defs)

new_rules=()
for PARTITION in $(findmnt -n -l -k -it \
    $(awk '/nodev/{print $2}' /proc/filesystems | paste -sd,) \
    | grep -Pv "noexec|nosuid" | awk '{print $1}'); do
    while IFS= read -r priv; do
        new_rules+=("-a always,exit -F path=${priv} -F perm=x -F auid>=${uid_min} -F auid!=unset -k privileged")
    done < <(find "${PARTITION}" -xdev -perm /6000 -type f 2>/dev/null)
done

old_rules=()
[ -f "$rules_file" ] && readarray -t old_rules < "$rules_file"
printf '%s\n' "${old_rules[@]}" "${new_rules[@]}" | sort -u > "$rules_file"

augenrules --load 2>/dev/null

fail=0
for PARTITION in $(findmnt -n -l -k -it \
    $(awk '/nodev/{print $2}' /proc/filesystems | paste -sd,) \
    | grep -Pv "noexec|nosuid" | awk '{print $1}'); do
    while IFS= read -r priv; do
        grep -qr "$priv" "$AR_rules_dir"/ 2>/dev/null || { fail=1; break 2; }
    done < <(find "${PARTITION}" -xdev -perm /6000 -type f 2>/dev/null)
done

[ "$fail" -eq 0 ] \
    && echo -e "${GREEN}SUCCESS${RESET}" \
    || { echo -e "${RED}FAILED${RESET}"; exit 1; }
exit 0