#!/usr/bin/env bash
NAME="ensure the audit configuration is immutable"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$LOGGING_RAM_STORE" ] && source "$LOGGING_RAM_STORE" || { echo -e "${RED}FAILED${RESET}"; exit 1; }

idx=$(get_ar_group_index "immutable")
file_var="AR_${idx}_file"; rules_file="${AR_rules_dir}/${!file_var}"

grep -qP '^\s*-e\s+2\b' "$rules_file" 2>/dev/null \
    || printf '\n%s\n' "-e 2" >> "$rules_file"

augenrules --load 2>/dev/null; 

result=$(grep -Ph -- '^\s*-e\s+2\b' "$AR_rules_dir"/*.rules 2>/dev/null | tail -1)
[ -n "$result" ] \
    && echo -e "${GREEN}SUCCESS${RESET}" \
    || { echo -e "${RED}FAILED${RESET}"; exit 1; }
exit 0