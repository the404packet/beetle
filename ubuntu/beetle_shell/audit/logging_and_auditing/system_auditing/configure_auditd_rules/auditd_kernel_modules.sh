#!/usr/bin/env bash
NAME="ensure kernel module loading unloading and modification is collected"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$LOGGING_RAM_STORE" ] && source "$LOGGING_RAM_STORE" || { echo -e "${RED}NOT HARDENED${RESET}"; exit 0; }

UID_MIN=$(awk '/^\s*UID_MIN/{print $2}' /etc/login.defs)
[ -z "$UID_MIN" ] && { echo -e "${RED}NOT HARDENED${RESET}"; exit 0; }

syscalls=$(awk '/^ *-a *always,exit/ \
&&/ -F *arch=b(32|64)/ \
&&(/ -F *auid!=unset/||/ -F *auid!=-1/||/ -F *auid!=4294967295/) \
&&/ -S/ \
&&(/init_module/||/finit_module/||/delete_module/||/create_module/||/query_module/) \
&&(/ key= *[!-~]* *$|/ -k *[!-~]* *$/)' \
"$AR_rules_dir"/*.rules 2>/dev/null)

kmod=$(awk "/^ *-a *always,exit/ \
&&(/ -F *auid!=unset/||/ -F *auid!=-1/||/ -F *auid!=4294967295/) \
&&/ -F *auid>=${UID_MIN}/ \
&&/ -F *perm=x/ \
&&/ -F *path=\/usr\/bin\/kmod/" \
"$AR_rules_dir"/*.rules 2>/dev/null)

[ -n "$syscalls" ] && [ -n "$kmod" ] \
    && echo -e "${GREEN}HARDENED${RESET}" \
    || echo -e "${RED}NOT HARDENED${RESET}"
exit 0