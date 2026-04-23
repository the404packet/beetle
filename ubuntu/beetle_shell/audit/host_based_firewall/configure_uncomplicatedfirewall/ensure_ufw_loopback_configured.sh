#!/usr/bin/env bash
# =============================================================================
# audit/host_based_firewall/4.2/ensure_ufw_loopback_configured.sh
# CIS Ubuntu Benchmark — 4.2.4
# Ensure ufw loopback traffic is configured (Automated)
#
# Checks: ALLOW IN/OUT on lo, DENY IN from 127.0.0.0/8 and ::1 (if IPv6)
# =============================================================================
NAME="ensure ufw loopback traffic is configured"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$FW_RAM_STORE" ] && source "$FW_RAM_STORE"

rules=$(ufw status verbose 2>/dev/null)
echo "$rules" | grep -q "on ${UFW_lb_allow_in}"     || { echo -e "${RED}NOT HARDENED${RESET}"; exit 0; }
echo "$rules" | grep -q "out on ${UFW_lb_allow_out}" || { echo -e "${RED}NOT HARDENED${RESET}"; exit 0; }
echo "$rules" | grep -q "${UFW_lb_deny_in}"          || { echo -e "${RED}NOT HARDENED${RESET}"; exit 0; }
grep -qi "^IPV6=yes" /etc/default/ufw 2>/dev/null \
    && { echo "$rules" | grep -q "${UFW_lb_deny_in6}" || { echo -e "${RED}NOT HARDENED${RESET}"; exit 0; }; }
echo -e "${GREEN}HARDENED${RESET}"; exit 0
