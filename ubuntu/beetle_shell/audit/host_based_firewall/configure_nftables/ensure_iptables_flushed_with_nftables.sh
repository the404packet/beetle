#!/usr/bin/env bash
# =============================================================================
# audit/host_based_firewall/4.3/ensure_iptables_flushed_with_nftables.sh
# CIS Ubuntu Benchmark — 4.3.3
# Ensure iptables are flushed with nftables (Manual)
#
# Leftover iptables rules interfere with nftables in netfilter
# =============================================================================
NAME="ensure iptables are flushed with nftables"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"

for cmd in iptables ip6tables; do
    rules=$(${cmd} -L 2>/dev/null | grep -v "^Chain\|^target\|^$")
    [ -n "$rules" ] && { echo -e "${RED}NOT HARDENED${RESET}"; exit 0; }
done
echo -e "${GREEN}HARDENED${RESET}"; exit 0
