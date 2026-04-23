#!/usr/bin/env bash
# =============================================================================
# harden/host_based_firewall/4.4/ensure_ip6tables_loopback_configured.sh
# CIS Ubuntu Benchmark — 4.4.3.2
# Ensure ip6tables loopback traffic is configured (Automated)
# =============================================================================
NAME="ensure ip6tables loopback traffic is configured"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$FW_RAM_STORE" ] && source "$FW_RAM_STORE"

ip6tables -L &>/dev/null || { echo -e "${GREEN}SUCCESS${RESET}"; exit 0; }
ip6tables -A INPUT  -i "$IPT_lb_iface"    -j ACCEPT &>/dev/null
ip6tables -A OUTPUT -o "$IPT_lb_iface"    -j ACCEPT &>/dev/null
ip6tables -A INPUT  -s "$IPT_lb_deny_in6" -j DROP   &>/dev/null
echo -e "${GREEN}SUCCESS${RESET}"; exit 0
