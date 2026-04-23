#!/usr/bin/env bash
# =============================================================================
# harden/host_based_firewall/4.4/ensure_iptables_open_ports_have_rules.sh
# CIS Ubuntu Benchmark — 4.4.2.4
# Ensure iptables firewall rules exist for all open ports (Automated)
#
# Note: Adds generic TCP ACCEPT per unmatched port — review after hardening
# =============================================================================
NAME="ensure iptables firewall rules exist for all open ports"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"

open_ports=$(ss -tuln 2>/dev/null | awk 'NR>1{print $5}' \
             | grep -oP '(?<=:)\d+$' | sort -un)
ipt_rules=$(iptables -L INPUT 2>/dev/null)
for port in $open_ports; do
    echo "$ipt_rules" | grep -qw "dpt:${port}" && continue
    iptables -A INPUT -p tcp --dport "$port" -j ACCEPT &>/dev/null \
        || { echo -e "${RED}FAILED${RESET}"; exit 1; }
done
echo -e "${GREEN}SUCCESS${RESET}"; exit 0
