#!/usr/bin/env bash
# =============================================================================
# audit/host_based_firewall/4.4/ensure_iptables_default_deny_policy.sh
# CIS Ubuntu Benchmark — 4.4.2.1
# Ensure iptables default deny firewall policy (Automated)
#
# Reads expected policies from firewall.json → iptables.default_policies
# =============================================================================
NAME="ensure iptables default deny firewall policy"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$FW_RAM_STORE" ] && source "$FW_RAM_STORE"

for chain in INPUT FORWARD OUTPUT; do
    policy_var="IPT_policy_$(echo "$chain" | tr '[:upper:]' '[:lower:]')"
    expected="${!policy_var}"
    actual=$(iptables -L "$chain" 2>/dev/null | awk 'NR==1{print $NF}' | tr -d '()')
    [ "$actual" = "$expected" ] || { echo -e "${RED}NOT HARDENED${RESET}"; exit 0; }
done
echo -e "${GREEN}HARDENED${RESET}"; exit 0
