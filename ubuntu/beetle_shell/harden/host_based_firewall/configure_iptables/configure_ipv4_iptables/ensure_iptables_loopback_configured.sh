#!/usr/bin/env bash
# =============================================================================
# harden/host_based_firewall/4.4/ensure_iptables_loopback_configured.sh
# CIS Ubuntu Benchmark — 4.4.2.2
# Ensure iptables loopback traffic is configured (Automated)
# =============================================================================
NAME="ensure iptables loopback traffic is configured"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$FW_RAM_STORE" ] && source "$FW_RAM_STORE"

iptables -A INPUT  -i "$IPT_lb_iface"   -j ACCEPT &>/dev/null
iptables -A OUTPUT -o "$IPT_lb_iface"   -j ACCEPT &>/dev/null
iptables -A INPUT  -s "$IPT_lb_deny_in" -j DROP   &>/dev/null
echo -e "${GREEN}SUCCESS${RESET}"; exit 0
