#!/usr/bin/env bash
NAME="ensure successful file system mounts are collected"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$LOGGING_RAM_STORE" ] && source "$LOGGING_RAM_STORE" || { echo -e "${RED}NOT HARDENED${RESET}"; exit 0; }

UID_MIN=$(awk '/^\s*UID_MIN/{print $2}' /etc/login.defs)
[ -z "$UID_MIN" ] && { echo -e "${RED}NOT HARDENED${RESET}"; exit 0; }

on_disk=$(awk "/^ *-a *always,exit/ &&/ -F *arch=b(32|64)/ \
&&(/ -F *auid!=unset/||/ -F *auid!=-1/||/ -F *auid!=4294967295/) \
&&/ -F *auid>=${UID_MIN}/ &&/ -S/ &&/mount/ \
&&(/ key= *[!-~]* *$|/ -k *[!-~]* *$/)" \
"$AR_rules_dir"/*.rules 2>/dev/null)

running=$(auditctl -l 2>/dev/null | awk "/^ *-a *always,exit/ \
&&/ -F *arch=b(32|64)/ &&/ -F *auid>=${UID_MIN}/ &&/ -S/ &&/mount/")

[ -n "$on_disk" ] && [ -n "$running" ] \
    && echo -e "${GREEN}HARDENED${RESET}" \
    || echo -e "${RED}NOT HARDENED${RESET}"
exit 0