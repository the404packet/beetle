#!/usr/bin/env bash
NAME="ensure kernel module loading unloading and modification is collected"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$LOGGING_RAM_STORE" ] && source "$LOGGING_RAM_STORE" || { echo -e "${RED}FAILED${RESET}"; exit 1; }

UID_MIN=$(awk '/^\s*UID_MIN/{print $2}' /etc/login.defs)
[ -z "$UID_MIN" ] && { echo -e "${RED}FAILED${RESET}"; exit 1; }

idx=$(get_ar_group_index "kernel_modules")
file_var="AR_${idx}_file"; rules_file="${AR_rules_dir}/${!file_var}"
key_var="AR_${idx}_key"; key="${!key_var}"

rules=(
    "-a always,exit -F arch=b64 -S init_module,finit_module,delete_module,create_module,query_module -F auid>=${UID_MIN} -F auid!=unset -k ${key}"
    "-a always,exit -F path=/usr/bin/kmod -F perm=x -F auid>=${UID_MIN} -F auid!=unset -k ${key}"
)
for rule in "${rules[@]}"; do
    grep -qF -- "$rule" "$rules_file" 2>/dev/null || echo "$rule" >> "$rules_file"
done

augenrules --load 2>/dev/null; 

syscalls=$(awk '/init_module/' "$AR_rules_dir"/*.rules 2>/dev/null)
kmod=$(grep -r '/usr/bin/kmod' "$AR_rules_dir"/ 2>/dev/null)

[ -n "$syscalls" ] && [ -n "$kmod" ] \
    && echo -e "${GREEN}SUCCESS${RESET}" \
    || { echo -e "${RED}FAILED${RESET}"; exit 1; }
exit 0