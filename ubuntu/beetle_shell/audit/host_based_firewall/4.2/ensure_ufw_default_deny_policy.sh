#!/usr/bin/env bash
# =============================================================================
# audit/host_based_firewall/4.2/ensure_ufw_default_deny_policy.sh
# CIS Ubuntu Benchmark — 4.2.7
# Ensure ufw default deny firewall policy (Automated)
# =============================================================================
NAME="ensure ufw default deny firewall policy"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$FW_RAM_STORE" ] && source "$FW_RAM_STORE"

out=$(ufw status verbose 2>/dev/null)
echo "$out" | grep -qi "Default:.*${UFW_policy_incoming}.*\(incoming\)" \
    || { echo -e "${RED}NOT HARDENED${RESET}"; exit 0; }
echo "$out" | grep -qi "${UFW_policy_routed}.*\(routed\)"               \
    || { echo -e "${RED}NOT HARDENED${RESET}"; exit 0; }
echo -e "${GREEN}HARDENED${RESET}"; exit 0
