#!/usr/bin/env bash
NAME="ensure successful and unsuccessful attempts to use setfacl are collected"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$LOGGING_RAM_STORE" ] && source "$LOGGING_RAM_STORE" || { echo -e "${RED}NOT HARDENED${RESET}"; exit 0; }

UID_MIN=$(awk '/^\s*UID_MIN/{print $2}' /etc/login.defs)
[ -z "$UID_MIN" ] && { echo -e "${RED}NOT HARDENED${RESET}"; exit 0; }

idx=$(get_ar_group_index "perm_chng")
path_var="AR_${idx}_path_1"; path="${!path_var}"

on_disk=$(awk "/^ *-a *always,exit/ \
&&(/ -F *auid!=unset/||/ -F *auid!=-1/||/ -F *auid!=4294967295/) \
&&/ -F *auid>=${UID_MIN}/ \
&&/ -F *perm=x/ \
&&/ -F *path=${path//\//\\/}/ \
&&(/ key= *[!-~]* *$|/ -k *[!-~]* *$/)" \
"$AR_rules_dir"/*.rules 2>/dev/null)

[ -n "$on_disk" ] \
    && echo -e "${GREEN}HARDENED${RESET}" \
    || echo -e "${RED}NOT HARDENED${RESET}"
exit 0