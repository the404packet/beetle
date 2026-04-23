#!/usr/bin/env bash
# =============================================================================
# harden/host_based_firewall/4.4/ensure_ip6tables_default_deny_policy.sh
# CIS Ubuntu Benchmark — 4.4.3.1
# Ensure ip6tables default deny firewall policy (Automated)
# =============================================================================
NAME="ensure ip6tables default deny firewall policy"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$FW_RAM_STORE" ] && source "$FW_RAM_STORE"

ip6tables -L &>/dev/null || { echo -e "${GREEN}SUCCESS${RESET}"; exit 0; }
for chain in INPUT FORWARD OUTPUT; do
    policy_var="IPT_policy_$(echo "$chain" | tr '[:upper:]' '[:lower:]')"
    policy="${!policy_var}"
    ip6tables -P "$chain" "$policy" &>/dev/null \
        || { echo -e "${RED}FAILED${RESET}"; exit 1; }
done
echo -e "${GREEN}SUCCESS${RESET}"; exit 0
