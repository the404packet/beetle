#!/usr/bin/env bash
# =============================================================================
# harden/host_based_firewall/4.1/ensure_single_firewall_utility.sh
# CIS Ubuntu Benchmark — 4.1.1
# Ensure a single firewall configuration utility is in use (Automated)
#
# Action: Disables all backends then enables only active_tool from firewall.json
# =============================================================================
NAME="ensure single firewall utility is in use"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$DPKG_RAM_STORE" ] && source "$DPKG_RAM_STORE"
[ -f "$FW_RAM_STORE"   ] && source "$FW_RAM_STORE"

active="$FW_active_tool"
[ -z "$active" ] && { echo -e "${RED}FAILED — FW_active_tool not set in firewall.json${RESET}"; exit 1; }

_disable() { systemctl stop "$1" &>/dev/null; systemctl disable "$1" &>/dev/null; }

case "$active" in
    ufw)
        _disable nftables; _disable iptables
        systemctl enable --now ufw &>/dev/null || { echo -e "${RED}FAILED${RESET}"; exit 1; }
        ;;
    nftables)
        _disable ufw; _disable iptables
        systemctl enable --now nftables &>/dev/null || { echo -e "${RED}FAILED${RESET}"; exit 1; }
        ;;
    iptables)
        _disable ufw; _disable nftables
        ;;
    *)
        echo -e "${RED}FAILED — unknown active_tool: $active${RESET}"; exit 1
        ;;
esac
echo -e "${GREEN}SUCCESS${RESET}"; exit 0
