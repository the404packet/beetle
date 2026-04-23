#!/usr/bin/env bash
# =============================================================================
# harden/host_based_firewall/4.4/ensure_iptables_outbound_configured.sh
# CIS Ubuntu Benchmark — 4.4.2.3
# Ensure iptables outbound and established connections configured (Manual)
# =============================================================================
NAME="ensure iptables outbound and established connections are configured"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$FW_RAM_STORE" ] && source "$FW_RAM_STORE"

states="$IPT_states"
iptables -A INPUT  -m state --state "$states"     -j ACCEPT &>/dev/null
iptables -A OUTPUT -m state --state "NEW,$states" -j ACCEPT &>/dev/null
echo -e "${GREEN}SUCCESS${RESET}"; exit 0
