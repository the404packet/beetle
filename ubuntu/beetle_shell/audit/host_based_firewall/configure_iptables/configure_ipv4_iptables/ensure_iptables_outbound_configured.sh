#!/usr/bin/env bash
# =============================================================================
# audit/host_based_firewall/4.4/ensure_iptables_outbound_configured.sh
# CIS Ubuntu Benchmark — 4.4.2.3
# Ensure iptables outbound and established connections configured (Manual)
# =============================================================================
NAME="ensure iptables outbound and established connections are configured"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"

iptables -L INPUT  2>/dev/null | grep -q "ACCEPT.*state.*ESTABLISHED" \
    || { echo -e "${RED}NOT HARDENED${RESET}"; exit 0; }
iptables -L OUTPUT 2>/dev/null | grep -q "ACCEPT.*state.*NEW"          \
    || { echo -e "${RED}NOT HARDENED${RESET}"; exit 0; }
echo -e "${GREEN}HARDENED${RESET}"; exit 0
