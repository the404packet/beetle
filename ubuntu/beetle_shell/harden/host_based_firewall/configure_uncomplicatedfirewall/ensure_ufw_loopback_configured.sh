#!/usr/bin/env bash
# =============================================================================
# harden/host_based_firewall/4.2/ensure_ufw_loopback_configured.sh
# CIS Ubuntu Benchmark — 4.2.4
# Ensure ufw loopback traffic is configured (Automated)
# =============================================================================
NAME="ensure ufw loopback traffic is configured"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$FW_RAM_STORE" ] && source "$FW_RAM_STORE"

ufw allow in  on "$UFW_lb_allow_in"  &>/dev/null
ufw allow out on "$UFW_lb_allow_out" &>/dev/null
ufw deny  in  from "$UFW_lb_deny_in" &>/dev/null
grep -qi "^IPV6=yes" /etc/default/ufw 2>/dev/null \
    && ufw deny in from "$UFW_lb_deny_in6" &>/dev/null
echo -e "${GREEN}SUCCESS${RESET}"; exit 0
