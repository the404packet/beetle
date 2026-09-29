#!/usr/bin/env bash
# =============================================================================
# ubuntu/tests/hostbasedfirewall/restore.sh
# Automated Test Suite: Restoration and Cleanup for hostbasedfirewall
# =============================================================================

set -e

BACKUP_DIR="/tmp/beetle_hostbasedfirewall_backup"
MODULE_NAME="hostbasedfirewall"

# -----------------------------------------------------------------------------
# ROOT CHECK
# -----------------------------------------------------------------------------
if [[ "$EUID" -ne 0 ]]; then
    echo "[!] restore.sh must be run as root"
    exit 1
fi

echo "[*] Initializing restoration for $MODULE_NAME from $BACKUP_DIR..."

if [[ ! -d "$BACKUP_DIR" ]]; then
    echo "[*] Backup directory $BACKUP_DIR not found. Nothing to restore."
    exit 0
fi

# -----------------------------------------------------------------------------
# 1. KILL DUMMY TEST PROCESSES & LISTENERS
# -----------------------------------------------------------------------------
if [[ -f "$BACKUP_DIR/dummy_listener.pid" ]]; then
    kill -9 "$(cat "$BACKUP_DIR/dummy_listener.pid")" 2>/dev/null || true
    rm -f "$BACKUP_DIR/dummy_listener.pid"
fi
pkill -f "nc -l.*9999" 2>/dev/null || true

# -----------------------------------------------------------------------------
# 2. RESTORE FIREWALL RULES & NETWORK CONFIGURATIONS
# -----------------------------------------------------------------------------
echo "[*] Restoring firewall rules and configurations..."

# Restore UFW configurations & files
if [[ -f "$BACKUP_DIR/ufw_config.tar.gz" ]]; then
    echo "    [+] Restoring UFW config files..."
    tar -xzf "$BACKUP_DIR/ufw_config.tar.gz" -C / 2>/dev/null || true
fi

# Restore UFW active state
if [[ -f "$BACKUP_DIR/ufw_status.txt" ]] && command -v ufw &>/dev/null; then
    if grep -q "Status: active" "$BACKUP_DIR/ufw_status.txt"; then
        echo "    [+] Re-enabling UFW..."
        ufw --force enable &>/dev/null || true
    else
        echo "    [+] Disabling UFW..."
        ufw --force disable &>/dev/null || true
    fi
fi

# Restore iptables & ip6tables rules & configs
if [[ -f "$BACKUP_DIR/iptables.rules" ]] && command -v iptables-restore &>/dev/null; then
    echo "    [+] Restoring iptables rules..."
    iptables-restore < "$BACKUP_DIR/iptables.rules" 2>/dev/null || true
fi

if [[ -f "$BACKUP_DIR/ip6tables.rules" ]] && command -v ip6tables-restore &>/dev/null; then
    echo "    [+] Restoring ip6tables rules..."
    ip6tables-restore < "$BACKUP_DIR/ip6tables.rules" 2>/dev/null || true
fi

if [[ -f "$BACKUP_DIR/iptables_config.tar.gz" ]]; then
    echo "    [+] Restoring iptables config files..."
    tar -xzf "$BACKUP_DIR/iptables_config.tar.gz" -C / 2>/dev/null || true
fi

# Restore nftables rules & configs
if [[ -f "$BACKUP_DIR/nftables.rules" ]] && command -v nft &>/dev/null; then
    echo "    [+] Restoring nftables rules..."
    nft -f "$BACKUP_DIR/nftables.rules" 2>/dev/null || nft flush ruleset 2>/dev/null || true
fi

if [[ -f "$BACKUP_DIR/nftables.conf.bak" ]]; then
    echo "    [+] Restoring /etc/nftables.conf..."
    cp -a "$BACKUP_DIR/nftables.conf.bak" /etc/nftables.conf 2>/dev/null || true
elif [[ -f "/etc/nftables.conf" ]]; then
    # If /etc/nftables.conf did not exist before test, remove test artifact
    rm -f /etc/nftables.conf 2>/dev/null || true
fi

if [[ -f "$BACKUP_DIR/nftables_config.tar.gz" ]]; then
    echo "    [+] Restoring nftables directory..."
    tar -xzf "$BACKUP_DIR/nftables_config.tar.gz" -C / 2>/dev/null || true
fi

# -----------------------------------------------------------------------------
# 3. RESTORE SYSTEMD SERVICES
# -----------------------------------------------------------------------------
echo "[*] Restoring systemd services to original states..."
if [[ -f "$BACKUP_DIR/services.txt" ]]; then
    while read -r svc enabled active; do
        [[ -z "$svc" ]] && continue
        case "$enabled" in
            enabled)
                systemctl unmask "$svc" &>/dev/null || true
                systemctl enable "$svc" &>/dev/null || true
                ;;
            disabled)
                systemctl unmask "$svc" &>/dev/null || true
                systemctl disable "$svc" &>/dev/null || true
                ;;
            masked)
                systemctl mask "$svc" &>/dev/null || true
                ;;
        esac

        case "$active" in
            active)
                systemctl start "$svc" &>/dev/null || true
                ;;
            inactive)
                systemctl stop "$svc" &>/dev/null || true
                ;;
        esac
    done < "$BACKUP_DIR/services.txt"
fi

# -----------------------------------------------------------------------------
# 4. RESTORE SYSCTL PARAMETERS & KERNEL MODULE CONFIGS
# -----------------------------------------------------------------------------
echo "[*] Restoring sysctl runtime parameters and modprobe configs..."
if [[ -f "$BACKUP_DIR/sysctl.txt" ]]; then
    while IFS=' = ' read -r key val; do
        [[ -n "$key" && -n "$val" ]] && sysctl -w "$key=$val" &>/dev/null || true
    done < "$BACKUP_DIR/sysctl.txt"
fi

if [[ -f "$BACKUP_DIR/modprobe.tar.gz" ]]; then
    tar -xzf "$BACKUP_DIR/modprobe.tar.gz" -C / 2>/dev/null || true
fi

# -----------------------------------------------------------------------------
# 5. RESTORE SYSTEM FILE PERMISSIONS & METADATA
# -----------------------------------------------------------------------------
echo "[*] Restoring file permissions, owner, and group metadata..."
if [[ -f "$BACKUP_DIR/file_perms.txt" ]]; then
    while read -r fpath mode owner group; do
        if [[ -e "$fpath" && -n "$mode" && -n "$owner" && -n "$group" ]]; then
            chmod "$mode" "$fpath" 2>/dev/null || true
            chown "$owner:$group" "$fpath" 2>/dev/null || true
        fi
    done < "$BACKUP_DIR/file_perms.txt"
fi

# -----------------------------------------------------------------------------
# 6. CLEAN UP TEMPORARY TEST ARTIFACTS
# -----------------------------------------------------------------------------
echo "[*] Cleaning up temporary test files..."
rm -f /tmp/beetle_test_* /dev/shm/beetle_test_* 2>/dev/null || true
if command -v load_dpkg &>/dev/null; then
    load_dpkg &>/dev/null || true
fi
rm -rf "$BACKUP_DIR"

echo "[+] State restoration complete for $MODULE_NAME. All pre-test settings restored."
exit 0
