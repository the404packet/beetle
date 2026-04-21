#!/usr/bin/env bash
NAME="ensure events that modify the system network environment are collected"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$LOGGING_RAM_STORE" ] && source "$LOGGING_RAM_STORE" || { echo -e "${RED}FAILED${RESET}"; exit 1; }

idx=$(get_ar_group_index "system_locale")
file_var="AR_${idx}_file"; rules_file="${AR_rules_dir}/${!file_var}"
count_var="AR_${idx}_rule_count"; count="${!count_var}"

for ((j=0; j<count; j++)); do
    r_var="AR_${idx}_${j}_rule"; rule="${!r_var}"
    grep -qF -- "$rule" "$rules_file" 2>/dev/null || echo "$rule" >> "$rules_file"
done

augenrules --load 2>/dev/null

fail=0
for ((j=0; j<count; j++)); do
    r_var="AR_${idx}_${j}_rule"; rule="${!r_var}"
    grep -qrF -- "$rule" "$AR_rules_dir"/ 2>/dev/null || fail=1
done

[ "$fail" -eq 0 ] \
    && echo -e "${GREEN}SUCCESS${RESET}" \
    || { echo -e "${RED}FAILED${RESET}"; exit 1; }
exit 0