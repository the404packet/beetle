#!/usr/bin/env bash
# =============================================================================
# audit/host_based_firewall/4.4/ensure_ip6tables_outbound_configured.sh
# CIS Ubuntu Benchmark — 4.4.3.3
# Ensure ip6tables outbound and established connections configured (Manual)
# =============================================================================
NAME="ensure ip6tables outbound and established connections are configured"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"

ip6tables -L &>/dev/null || { echo -e "${GREEN}HARDENED${RESET}"; exit 0; }
ip6tables -L INPUT  2>/dev/null | grep -q "ACCEPT.*state.*ESTABLISHED" \
    || { echo -e "${RED}NOT HARDENED${RESET}"; exit 0; }
ip6tables -L OUTPUT 2>/dev/null | grep -q "ACCEPT.*state.*NEW"          \
    || { echo -e "${RED}NOT HARDENED${RESET}"; exit 0; }
echo -e "${GREEN}HARDENED${RESET}"; exit 0
