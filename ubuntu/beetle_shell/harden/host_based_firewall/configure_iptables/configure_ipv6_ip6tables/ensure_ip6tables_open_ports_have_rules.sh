#!/usr/bin/env bash
# =============================================================================
# harden/host_based_firewall/4.4/ensure_ip6tables_open_ports_have_rules.sh
# CIS Ubuntu Benchmark — 4.4.3.4
# Ensure ip6tables firewall rules exist for all open ports (Automated)
#
# Note: Adds generic TCP ACCEPT per unmatched port — review after hardening
# =============================================================================
NAME="ensure ip6tables firewall rules exist for all open ports"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"

ip6tables -L &>/dev/null || { echo -e "${GREEN}SUCCESS${RESET}"; exit 0; }
open_ports=$(ss -tuln 2>/dev/null | awk 'NR>1{print $5}' \
             | grep -oP '(?<=:)\d+$' | sort -un)
ipt_rules=$(ip6tables -L INPUT 2>/dev/null)
for port in $open_ports; do
    echo "$ipt_rules" | grep -qw "dpt:${port}" && continue
    ip6tables -A INPUT -p tcp --dport "$port" -j ACCEPT &>/dev/null \
        || { echo -e "${RED}FAILED${RESET}"; exit 1; }
done
echo -e "${GREEN}SUCCESS${RESET}"; exit 0
