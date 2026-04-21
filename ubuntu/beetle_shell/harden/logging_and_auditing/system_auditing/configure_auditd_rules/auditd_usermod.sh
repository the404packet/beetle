#!/usr/bin/env bash
NAME="ensure usermod command use is collected"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$LOGGING_RAM_STORE" ] && source "$LOGGING_RAM_STORE" || { echo -e "${RED}FAILED${RESET}"; exit 1; }

UID_MIN=$(awk '/^\s*UID_MIN/{print $2}' /etc/login.defs)
[ -z "$UID_MIN" ] && { echo -e "${RED}FAILED${RESET}"; exit 1; }

idx=$(get_ar_group_index "usermod")
file_var="AR_${idx}_file"; rules_file="${AR_rules_dir}/${!file_var}"
p_var="AR_${idx}_path_0"; path="${!p_var}"
key_var="AR_${idx}_key"; key="${!key_var}"

rule="-a always,exit -F path=${path} -F perm=x -F auid>=${UID_MIN} -F auid!=unset -k ${key}"
grep -qF -- "$rule" "$rules_file" 2>/dev/null || echo "$rule" >> "$rules_file"

augenrules --load 2>/dev/null; ar_check_reboot

grep -qrF -- "path=${path}" "$AR_rules_dir"/ 2>/dev/null \
    && echo -e "${GREEN}SUCCESS${RESET}" \
    || { echo -e "${RED}FAILED${RESET}"; exit 1; }
exit 0