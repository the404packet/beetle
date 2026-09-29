#!/usr/bin/env bash
# =============================================================================
# ubuntu/tests/hostbasedfirewall/unsecure.sh
# Automated Test Suite: Initial State Backup and Unsecuring for hostbasedfirewall
# =============================================================================

set -e

BACKUP_DIR="/tmp/beetle_hostbasedfirewall_backup"
MODULE_NAME="hostbasedfirewall"

# -----------------------------------------------------------------------------
# ROOT CHECK
# -----------------------------------------------------------------------------
if [[ "$EUID" -ne 0 ]]; then
    echo "[!] unsecure.sh must be run as root"
    exit 1
fi

echo "[*] Initializing pre-test backup for $MODULE_NAME in $BACKUP_DIR..."

# -----------------------------------------------------------------------------
# STEP 1: CAPTURE INITIAL STATE SNAPSHOT
# -----------------------------------------------------------------------------
if [[ -d "$BACKUP_DIR" ]]; then
    echo "[*] Backup directory $BACKUP_DIR already exists; preserving existing pre-test snapshot."
else
    mkdir -p "$BACKUP_DIR"
    chmod 700 "$BACKUP_DIR"

    # 1. Systemd Services Status & Package States
    echo "[*] Backing up systemd services and package states..."
    SERVICES=("ufw" "nftables" "iptables" "netfilter-persistent")
    > "$BACKUP_DIR/services.txt"
    for svc in "${SERVICES[@]}"; do
        enabled=$(systemctl is-enabled "$svc" 2>/dev/null || echo "not-found")
        active=$(systemctl is-active "$svc" 2>/dev/null || echo "inactive")
        echo "$svc $enabled $active" >> "$BACKUP_DIR/services.txt"
    done

    # Package installation state
    PACKAGES=("ufw" "nftables" "iptables" "iptables-persistent")
    dpkg-query -W -f='${Package} ${Status} ${Version}\n' "${PACKAGES[@]}" 2>/dev/null > "$BACKUP_DIR/packages.txt" || true

    # 2. Firewall Rules & Network Settings
    echo "[*] Backing up firewall rules and network settings..."
    # UFW
    if command -v ufw &>/dev/null; then
        ufw status verbose > "$BACKUP_DIR/ufw_status_verbose.txt" 2>/dev/null || true
        ufw status > "$BACKUP_DIR/ufw_status.txt" 2>/dev/null || true
    fi

    # Archive /etc/default/ufw and /etc/ufw if present
    UFW_ITEMS=()
    [[ -f "/etc/default/ufw" ]] && UFW_ITEMS+=("etc/default/ufw")
    [[ -d "/etc/ufw" ]] && UFW_ITEMS+=("etc/ufw")
    if [[ ${#UFW_ITEMS[@]} -gt 0 ]]; then
        tar -czf "$BACKUP_DIR/ufw_config.tar.gz" -C / "${UFW_ITEMS[@]}" 2>/dev/null || true
    fi

    # iptables & ip6tables rules
    if command -v iptables-save &>/dev/null; then
        iptables-save > "$BACKUP_DIR/iptables.rules" 2>/dev/null || true
    fi
    if command -v ip6tables-save &>/dev/null; then
        ip6tables-save > "$BACKUP_DIR/ip6tables.rules" 2>/dev/null || true
    fi

    # Archive /etc/iptables directory if present
    if [[ -d "/etc/iptables" ]]; then
        tar -czf "$BACKUP_DIR/iptables_config.tar.gz" -C / etc/iptables 2>/dev/null || true
    fi

    # nftables rules
    if command -v nft &>/dev/null; then
        nft list ruleset > "$BACKUP_DIR/nftables.rules" 2>/dev/null || true
    fi
    if [[ -f "/etc/nftables.conf" ]]; then
        cp -a /etc/nftables.conf "$BACKUP_DIR/nftables.conf.bak" 2>/dev/null || true
    fi
    if [[ -d "/etc/nftables" ]]; then
        tar -czf "$BACKUP_DIR/nftables_config.tar.gz" -C / etc/nftables 2>/dev/null || true
    fi

    # 3. Kernel Parameters & Modules
    echo "[*] Backing up kernel parameters and modules..."
    lsmod > "$BACKUP_DIR/lsmod.txt" 2>/dev/null || true
    sysctl -a 2>/dev/null | grep -E "^net\.(ipv4|ipv6|netfilter)\." > "$BACKUP_DIR/sysctl.txt" || true

    if [[ -d "/etc/modprobe.d" ]]; then
        tar -czf "$BACKUP_DIR/modprobe.tar.gz" -C / etc/modprobe.d 2>/dev/null || true
    fi

    # 4. System File Permissions & Content
    echo "[*] Backing up system file permissions and content..."
    FILES_TO_RECORD=(
        "/etc/default/ufw"
        "/etc/ufw/ufw.conf"
        "/etc/ufw/before.rules"
        "/etc/ufw/after.rules"
        "/etc/ufw/user.rules"
        "/etc/ufw/user6.rules"
        "/etc/nftables.conf"
        "/etc/iptables/rules.v4"
        "/etc/iptables/rules.v6"
    )
    > "$BACKUP_DIR/file_perms.txt"
    for f in "${FILES_TO_RECORD[@]}"; do
        if [[ -e "$f" ]]; then
            stat_meta=$(stat -c "%a %U %G" "$f" 2>/dev/null || true)
            echo "$f $stat_meta" >> "$BACKUP_DIR/file_perms.txt"
        fi
    done

    echo "[+] Initial system state successfully backed up to $BACKUP_DIR"
fi

# -----------------------------------------------------------------------------
# STEP 2: UNSECURE SYSTEM SETTINGS (TRIGGER NOT HARDENED AUDIT FAILURES)
# -----------------------------------------------------------------------------
echo "[*] Unsecuring firewall configurations to trigger audit failures (NOT HARDENED)..."
[[ -f "$FW_RAM_STORE" ]] && source "$FW_RAM_STORE"
fw_tool="${FW_active_tool:-ufw}"

# 1. Unsecure UFW:
# - Reset rules and disable
# - Set default policies to allow incoming & routed, reject outgoing
if command -v ufw &>/dev/null; then
    echo "    [-] Resetting UFW and inverting default policies..."
    ufw --force reset &>/dev/null || true
    ufw default allow incoming &>/dev/null || true
    ufw default allow routed &>/dev/null || true
    ufw default reject outgoing &>/dev/null || true
    if [[ "$fw_tool" == "ufw" ]]; then
        ufw --force disable &>/dev/null || true
    else
        ufw --force enable &>/dev/null || true
    fi
fi
if [[ "$fw_tool" == "ufw" ]]; then
    systemctl stop ufw &>/dev/null || true
    systemctl disable ufw &>/dev/null || true
else
    systemctl enable --now ufw &>/dev/null || true
fi

# 2. Unsecure nftables:
# - Flush live ruleset
# - Corrupt / overwrite rules file to break permanence check
# - Stop and disable service
if command -v nft &>/dev/null; then
    echo "    [-] Flushing nftables ruleset..."
    nft flush ruleset &>/dev/null || true
fi
if [[ -f "/etc/nftables.conf" ]]; then
    echo "# UNSECURED BY BEETLE TEST RUNNER" > /etc/nftables.conf
fi
if [[ "$fw_tool" == "nftables" ]]; then
    systemctl stop nftables &>/dev/null || true
    systemctl disable nftables &>/dev/null || true
else
    systemctl enable --now nftables &>/dev/null || true
fi

# 3. Unsecure iptables & ip6tables:
if command -v iptables &>/dev/null; then
    echo "    [-] Setting insecure iptables policies and clearing rules..."
    iptables -F &>/dev/null || true
    iptables -X &>/dev/null || true
    iptables -P INPUT ACCEPT &>/dev/null || true
    iptables -P FORWARD ACCEPT &>/dev/null || true
    iptables -P OUTPUT DROP &>/dev/null || true
    if [[ "$fw_tool" == "nftables" ]]; then
        iptables -A INPUT -p tcp --dport 9999 -j ACCEPT &>/dev/null || true
    fi
fi

if command -v ip6tables &>/dev/null; then
    echo "    [-] Setting insecure ip6tables policies and clearing rules..."
    ip6tables -F &>/dev/null || true
    ip6tables -X &>/dev/null || true
    ip6tables -P INPUT ACCEPT &>/dev/null || true
    ip6tables -P FORWARD ACCEPT &>/dev/null || true
    ip6tables -P OUTPUT DROP &>/dev/null || true
    if [[ "$fw_tool" == "nftables" ]]; then
        ip6tables -A INPUT -p tcp --dport 9999 -j ACCEPT &>/dev/null || true
    fi
fi

# 4. Start dummy background listener on port 9999 if no open ports exist
# (ensures open ports audit checks have an unmatched port and fail)
if ! ss -tuln 2>/dev/null | grep -q ":"; then
    if command -v nc &>/dev/null; then
        nc -l -p 9999 &>/dev/null &
        echo $! > "$BACKUP_DIR/dummy_listener.pid"
    elif command -v python3 &>/dev/null; then
        python3 -c 'import socket, time; s=socket.socket(); s.bind(("0.0.0.0", 9999)); s.listen(1); time.sleep(300)' &>/dev/null &
        echo $! > "$BACKUP_DIR/dummy_listener.pid"
    fi
fi

# 5. Unsecure package states in DPKG_RAM_STORE for the active tool
[[ -f "$FW_RAM_STORE" ]] && source "$FW_RAM_STORE"
fw_tool="${FW_active_tool:-ufw}"
if [[ -f "$DPKG_RAM_STORE" ]]; then
    echo "    [-] Priming package cache in DPKG_RAM_STORE..."
    case "$fw_tool" in
        ufw)
            sed -i '/^PKG_ufw=/d' "$DPKG_RAM_STORE"
            echo "PKG_ufw=not_installed" >> "$DPKG_RAM_STORE"
            sed -i '/^PKG_iptables_persistent=/d' "$DPKG_RAM_STORE"
            echo "PKG_iptables_persistent=installed" >> "$DPKG_RAM_STORE"
            ;;
        nftables)
            sed -i '/^PKG_nftables=/d' "$DPKG_RAM_STORE"
            echo "PKG_nftables=not_installed" >> "$DPKG_RAM_STORE"
            sed -i '/^PKG_ufw=/d' "$DPKG_RAM_STORE"
            echo "PKG_ufw=installed" >> "$DPKG_RAM_STORE"
            ;;
        iptables)
            sed -i '/^PKG_iptables=/d' "$DPKG_RAM_STORE"
            echo "PKG_iptables=not_installed" >> "$DPKG_RAM_STORE"
            sed -i '/^PKG_iptables_persistent=/d' "$DPKG_RAM_STORE"
            echo "PKG_iptables_persistent=not_installed" >> "$DPKG_RAM_STORE"
            sed -i '/^PKG_ufw=/d' "$DPKG_RAM_STORE"
            echo "PKG_ufw=installed" >> "$DPKG_RAM_STORE"
            sed -i '/^PKG_nftables=/d' "$DPKG_RAM_STORE"
            echo "PKG_nftables=installed" >> "$DPKG_RAM_STORE"
            ;;
    esac
fi

echo "[+] Unsecuring complete. All audit checks are primed to fail (NOT HARDENED)."
exit 0
