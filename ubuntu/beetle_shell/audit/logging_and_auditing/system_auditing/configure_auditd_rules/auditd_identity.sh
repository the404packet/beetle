#!/usr/bin/env bash
NAME="ensure events that modify user/group information are collected"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$LOGGING_RAM_STORE" ] && source "$LOGGING_RAM_STORE" || { echo -e "${RED}NOT HARDENED${RESET}"; exit 0; }

idx=$(get_ar_group_index "identity")
count_var="AR_${idx}_rule_count"; count="${!count_var}"

fail=0
for ((j=0; j<count; j++)); do
    r_var="AR_${idx}_${j}_rule"; rule="${!r_var}"
    grep -qrF -- "$rule" "$AR_rules_dir"/ 2>/dev/null || { fail=1; break; }
done
auditctl -l 2>/dev/null | grep -q "identity" || fail=1

[ "$fail" -eq 0 ] \
    && echo -e "${GREEN}HARDENED${RESET}" \
    || echo -e "${RED}NOT HARDENED${RESET}"
exit 0