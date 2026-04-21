#!/usr/bin/env bash
NAME="ensure discretionary access control permission modification events are collected"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$LOGGING_RAM_STORE" ] && source "$LOGGING_RAM_STORE" || { echo -e "${RED}FAILED${RESET}"; exit 1; }

UID_MIN=$(awk '/^\s*UID_MIN/{print $2}' /etc/login.defs)
[ -z "$UID_MIN" ] && { echo -e "${RED}FAILED${RESET}"; exit 1; }

idx=$(get_ar_group_index "perm_mod")
file_var="AR_${idx}_file"; rules_file="${AR_rules_dir}/${!file_var}"

rules=(
    "-a always,exit -F arch=b64 -S chmod,fchmod,fchmodat -F auid>=${UID_MIN} -F auid!=unset -F key=perm_mod"
    "-a always,exit -F arch=b64 -S chown,fchown,lchown,fchownat -F auid>=${UID_MIN} -F auid!=unset -F key=perm_mod"
    "-a always,exit -F arch=b32 -S chmod,fchmod,fchmodat -F auid>=${UID_MIN} -F auid!=unset -F key=perm_mod"
    "-a always,exit -F arch=b32 -S lchown,fchown,chown,fchownat -F auid>=${UID_MIN} -F auid!=unset -F key=perm_mod"
    "-a always,exit -F arch=b64 -S setxattr,lsetxattr,fsetxattr,removexattr,lremovexattr,fremovexattr -F auid>=${UID_MIN} -F auid!=unset -F key=perm_mod"
    "-a always,exit -F arch=b32 -S setxattr,lsetxattr,fsetxattr,removexattr,lremovexattr,fremovexattr -F auid>=${UID_MIN} -F auid!=unset -F key=perm_mod"
)
for rule in "${rules[@]}"; do
    grep -qF -- "$rule" "$rules_file" 2>/dev/null || echo "$rule" >> "$rules_file"
done

augenrules --load 2>/dev/null; 

on_disk=$(awk "/^ *-a *always,exit/ &&/ -F *arch=b(32|64)/ \
&&/ -F *auid>=${UID_MIN}/ &&/ -S/ \
&&(/chmod/||/fchmod/||/chown/||/setxattr/||/removexattr/)" \
"$AR_rules_dir"/*.rules 2>/dev/null | wc -l)

[ "$on_disk" -ge 6 ] \
    && echo -e "${GREEN}SUCCESS${RESET}" \
    || { echo -e "${RED}FAILED${RESET}"; exit 1; }
exit 0