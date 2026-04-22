#!/usr/bin/env bash
# =============================================================================
# harden/host_based_firewall/4.3/ensure_iptables_flushed_with_nftables.sh
# CIS Ubuntu Benchmark — 4.3.3
# Ensure iptables are flushed with nftables (Manual)
#
# -F flushes all rules, -X deletes all user-defined chains
# =============================================================================
NAME="ensure iptables are flushed with nftables"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"

for cmd in iptables ip6tables; do
    ${cmd} -F &>/dev/null || { echo -e "${RED}FAILED${RESET}"; exit 1; }
    ${cmd} -X &>/dev/null || { echo -e "${RED}FAILED${RESET}"; exit 1; }
done
echo -e "${GREEN}SUCCESS${RESET}"; exit 0
