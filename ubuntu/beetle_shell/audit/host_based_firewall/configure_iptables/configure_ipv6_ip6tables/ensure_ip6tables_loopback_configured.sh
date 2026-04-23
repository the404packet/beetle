#!/usr/bin/env bash
# =============================================================================
# audit/host_based_firewall/4.4/ensure_ip6tables_loopback_configured.sh
# CIS Ubuntu Benchmark — 4.4.3.2
# Ensure ip6tables loopback traffic is configured (Automated)
# =============================================================================
NAME="ensure ip6tables loopback traffic is configured"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$FW_RAM_STORE" ] && source "$FW_RAM_STORE"

ip6tables -L &>/dev/null || { echo -e "${GREEN}HARDENED${RESET}"; exit 0; }
ip6tables -L INPUT  2>/dev/null | grep -q "ACCEPT.*${IPT_lb_iface}"  || { echo -e "${RED}NOT HARDENED${RESET}"; exit 0; }
ip6tables -L OUTPUT 2>/dev/null | grep -q "ACCEPT.*${IPT_lb_iface}"  || { echo -e "${RED}NOT HARDENED${RESET}"; exit 0; }
ip6tables -L INPUT  2>/dev/null | grep -q "DROP.*${IPT_lb_deny_in6}" || { echo -e "${RED}NOT HARDENED${RESET}"; exit 0; }
echo -e "${GREEN}HARDENED${RESET}"; exit 0
