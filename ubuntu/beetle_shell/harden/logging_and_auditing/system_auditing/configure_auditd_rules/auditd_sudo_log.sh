#!/usr/bin/env bash
NAME="ensure events that modify the sudo log file are collected"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$LOGGING_RAM_STORE" ] && source "$LOGGING_RAM_STORE" || { echo -e "${RED}FAILED${RESET}"; exit 1; }

sudo_log=$(grep -r logfile /etc/sudoers* 2>/dev/null \
           | sed -e 's/.*logfile=//;s/,.*//' -e 's/"//g' | head -1)

if [ -z "$sudo_log" ]; then
    echo -e "${RED}FAILED${RESET}"; exit 1
fi

idx=$(get_ar_group_index "sudo_log_file")
file_var="AR_${idx}_file"; rules_file="${AR_rules_dir}/${!file_var}"

rule="-w ${sudo_log} -p wa -k sudo_log_file"
grep -qF -- "$rule" "$rules_file" 2>/dev/null || echo "$rule" >> "$rules_file"

augenrules --load 2>/dev/null

grep -qrF -- "$rule" "$AR_rules_dir"/ 2>/dev/null \
    && echo -e "${GREEN}SUCCESS${RESET}" \
    || { echo -e "${RED}FAILED${RESET}"; exit 1; }
exit 0