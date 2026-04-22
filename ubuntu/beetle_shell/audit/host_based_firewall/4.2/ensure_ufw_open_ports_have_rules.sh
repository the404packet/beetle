#!/usr/bin/env bash
# =============================================================================
# audit/host_based_firewall/4.2/ensure_ufw_open_ports_have_rules.sh
# CIS Ubuntu Benchmark — 4.2.6
# Ensure ufw firewall rules exist for all open ports (Automated)
# =============================================================================
NAME="ensure ufw firewall rules exist for all open ports"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"

open_ports=$(ss -tuln 2>/dev/null | awk 'NR>1{print $5}' \
             | grep -oP '(?<=:)\d+$' | sort -un)
ufw_rules=$(ufw status 2>/dev/null)
for port in $open_ports; do
    echo "$ufw_rules" | grep -qw "$port" \
        || { echo -e "${RED}NOT HARDENED${RESET}"; exit 0; }
done
echo -e "${GREEN}HARDENED${RESET}"; exit 0
