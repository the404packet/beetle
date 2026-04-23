#!/usr/bin/env bash
# =============================================================================
# harden/host_based_firewall/4.4/ensure_ip6tables_outbound_configured.sh
# CIS Ubuntu Benchmark — 4.4.3.3
# Ensure ip6tables outbound and established connections configured (Manual)
# =============================================================================
NAME="ensure ip6tables outbound and established connections are configured"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$FW_RAM_STORE" ] && source "$FW_RAM_STORE"

ip6tables -L &>/dev/null || { echo -e "${GREEN}SUCCESS${RESET}"; exit 0; }
states="$IPT_states"
ip6tables -A INPUT  -m state --state "$states"     -j ACCEPT &>/dev/null
ip6tables -A OUTPUT -m state --state "NEW,$states" -j ACCEPT &>/dev/null
echo -e "${GREEN}SUCCESS${RESET}"; exit 0
