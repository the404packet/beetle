#!/usr/bin/env bash
# =============================================================================
# audit/host_based_firewall/4.1/ensure_single_firewall_utility.sh
# CIS Ubuntu Benchmark — 4.1.1
# Ensure a single firewall configuration utility is in use (Automated)
#
# Pass:  Exactly one of ufw / nftables / iptables is active
# Fail:  Zero or more than one backend active simultaneously
# =============================================================================
# NAME="ensure single firewall utility is in use"
# GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
# [ -f "$DPKG_RAM_STORE" ] && source "$DPKG_RAM_STORE"
# [ -f "$FW_RAM_STORE"   ] && source "$FW_RAM_STORE"

# ufw_active=0
# nft_active=0
# ipt_active=0

# if is_package_installed "ufw" && systemctl is-enabled ufw &>/dev/null; then
#     ufw_active=1
# fi
# if is_package_installed "nftables" && systemctl is-enabled nftables &>/dev/null; then
#     nft_active=1
# fi
# # Standalone iptables is only counted if UFW is not managing it:
# if [ "$ufw_active" -eq 0 ] && is_package_installed "iptables"; then
#     if iptables -L INPUT 2>/dev/null | grep -qv "^Chain\|^target\|^$"; then
#         ipt_active=1
#     fi
# fi

# active_count=$(( ufw_active + nft_active + ipt_active ))

# [ "$active_count" -eq 1 ] \
#     && echo -e "${GREEN}HARDENED${RESET}" \
#     || echo -e "${RED}NOT HARDENED${RESET}"
# exit 0
#!/usr/bin/env bash
# =============================================================================
# audit/host_based_firewall/4.1/ensure_single_firewall_utility.sh
# =============================================================================
NAME="ensure single firewall utility is in use"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"

[ -f "$DPKG_RAM_STORE" ] && source "$DPKG_RAM_STORE"
[ -f "$FW_RAM_STORE" ] && source "$FW_RAM_STORE"

# Fallback just in case store isn't loaded
type is_package_installed &>/dev/null || is_package_installed() { dpkg -s "$1" &>/dev/null; }

ufw_active=0
nft_active=0
ipt_active=0

if is_package_installed "ufw" && systemctl is-enabled ufw &>/dev/null; then
    ufw_active=1
fi

if is_package_installed "nftables" && systemctl is-enabled nftables &>/dev/null; then
    nft_active=1
fi

# Standalone iptables is only counted if UFW is not managing it:
if [ "$ufw_active" -eq 0 ] && is_package_installed "iptables"; then
    if iptables -L INPUT 2>/dev/null | grep -qv "^Chain\|^target\|^$"; then
        ipt_active=1
    fi
fi

active_count=$(( ufw_active + nft_active + ipt_active ))

if [ "$active_count" -eq 1 ]; then
    echo -e "${GREEN}HARDENED${RESET}"
    exit 0
else
    echo -e "${RED}NOT HARDENED (Active count: $active_count)${RESET}"
    exit 1
fi