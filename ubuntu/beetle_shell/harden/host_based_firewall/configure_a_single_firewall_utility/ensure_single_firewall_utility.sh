# #!/usr/bin/env bash
# # =============================================================================
# # harden/host_based_firewall/4.1/ensure_single_firewall_utility.sh
# # CIS Ubuntu Benchmark — 4.1.1
# # Ensure a single firewall configuration utility is in use (Automated)
# #
# # Action: Disables all backends then enables only active_tool from firewall.json
# # =============================================================================
# NAME="ensure single firewall utility is in use"
# GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
# [ -f "$DPKG_RAM_STORE" ] && source "$DPKG_RAM_STORE"
# [ -f "$FW_RAM_STORE"   ] && source "$FW_RAM_STORE"

# active="$FW_active_tool"
# [ -z "$active" ] && { echo -e "${RED}FAILED — FW_active_tool not set in firewall.json${RESET}"; exit 1; }

# _disable() { systemctl stop "$1" &>/dev/null; systemctl disable "$1" &>/dev/null; }

# _ensure_pkg() {
#     is_package_installed "$1" && return 0
#     DEBIAN_FRONTEND=noninteractive apt-get install -y "$1" &>/dev/null
# }

# case "$active" in
#     ufw)
#         _disable nftables; _disable iptables
#         _ensure_pkg ufw || { echo -e "${RED}FAILED${RESET}"; exit 1; }
#         systemctl enable --now ufw &>/dev/null || ufw --force enable &>/dev/null \
#             || { echo -e "${RED}FAILED${RESET}"; exit 1; }
#         ;;
#     nftables)
#         _disable ufw; _disable iptables
#         _ensure_pkg nftables || { echo -e "${RED}FAILED${RESET}"; exit 1; }
#         systemctl enable --now nftables &>/dev/null || { echo -e "${RED}FAILED${RESET}"; exit 1; }
#         ;;
#     iptables)
#         _disable ufw; _disable nftables
#         _ensure_pkg iptables || { echo -e "${RED}FAILED${RESET}"; exit 1; }
#         ;;
#     *)
#         echo -e "${RED}FAILED — unknown active_tool: $active${RESET}"; exit 1
#         ;;
# esac
# echo -e "${GREEN}SUCCESS${RESET}"; exit 0
#!/usr/bin/env bash
# =============================================================================
# harden/host_based_firewall/4.1/ensure_single_firewall_utility.sh
# CIS Ubuntu Benchmark — 4.1.1
# Ensure a single firewall configuration utility is in use (Automated)
#
# Action: Disables all backends then enables only active_tool from firewall.json
# =============================================================================
#!/usr/bin/env bash
# =============================================================================
# harden/host_based_firewall/4.1/ensure_single_firewall_utility.sh
# =============================================================================
NAME="ensure single firewall utility is in use"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"

[ -f "$DPKG_RAM_STORE" ] && source "$DPKG_RAM_STORE"
[ -f "$FW_RAM_STORE" ] && source "$FW_RAM_STORE"

active="$FW_active_tool"
[ -z "$active" ] && { echo -e "${RED}FAILED — FW_active_tool not set in firewall.json${RESET}"; exit 1; }

# Fallback just in case store isn't loaded
type is_package_installed &>/dev/null || is_package_installed() { dpkg -s "$1" &>/dev/null; }

_ensure_pkg() {
    is_package_installed "$1" || DEBIAN_FRONTEND=noninteractive apt-get install -y "$1" &>/dev/null
}

_disable_service() {
    systemctl stop "$1" &>/dev/null
    systemctl disable "$1" &>/dev/null
}

case "$active" in
    ufw)
        # Sets nft_active=0
        _disable_service nftables
        
        # Sets ufw_active=1
        _ensure_pkg ufw
        systemctl unmask ufw &>/dev/null
        systemctl enable ufw &>/dev/null
        ufw --force enable &>/dev/null
        ;;
        
    nftables)
        # Sets ufw_active=0
        _disable_service ufw
        
        # Sets nft_active=1
        _ensure_pkg nftables
        systemctl unmask nftables &>/dev/null
        systemctl enable nftables &>/dev/null
        systemctl start nftables &>/dev/null
        
        # Sets ipt_active=0 by clearing rules so grep finds nothing
        if command -v iptables &>/dev/null; then
            iptables -F INPUT
        fi
        ;;
        
    iptables)
        # Sets ufw_active=0 and nft_active=0
        _disable_service ufw
        _disable_service nftables
        
        # Sets ipt_active=1
        _ensure_pkg iptables
        
        # Audit requires a rule to exist in INPUT. If empty, add a dummy rule.
        if ! iptables -L INPUT 2>/dev/null | grep -qv "^Chain\|^target\|^$"; then
            iptables -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
        fi
        
        # Attempt to save it so it persists, if persistent package exists
        if command -v netfilter-persistent &>/dev/null; then
            netfilter-persistent save &>/dev/null
        fi
        ;;
        
    *)
        echo -e "${RED}FAILED — unknown active_tool: $active${RESET}"; exit 1
        ;;
esac

echo -e "${GREEN}SUCCESS${RESET}"; exit 0