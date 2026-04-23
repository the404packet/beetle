#!/usr/bin/env bash
# =============================================================================
# audit/host_based_firewall/4.4/ensure_iptables_open_ports_have_rules.sh
# CIS Ubuntu Benchmark — 4.4.2.4
# Ensure iptables firewall rules exist for all open ports (Automated)
# =============================================================================
NAME="ensure iptables firewall rules exist for all open ports"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"

open_ports=$(ss -tuln 2>/dev/null | awk 'NR>1{print $5}' \
             | grep -oP '(?<=:)\d+$' | sort -un)
ipt_rules=$(iptables -L INPUT 2>/dev/null)
for port in $open_ports; do
    echo "$ipt_rules" | grep -qw "dpt:${port}" \
        || { echo -e "${RED}NOT HARDENED${RESET}"; exit 0; }
done
echo -e "${GREEN}HARDENED${RESET}"; exit 0
