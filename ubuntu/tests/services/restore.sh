#!/usr/bin/env bash
# =============================================================================
# ubuntu/tests/services/restore.sh
# Automated Test Suite: Restoration and Cleanup for services module
# =============================================================================

set -e

BACKUP_DIR="/tmp/beetle_services_backup"
MODULE_NAME="services"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BEETLE_SHELL_ROOT="$(cd "$SCRIPT_DIR/../../beetle_shell" && pwd)"
LIB_DIR="$BEETLE_SHELL_ROOT/lib"

# Root check
if [[ "$EUID" -ne 0 ]]; then
    echo "[!] restore.sh must be run as root"
    exit 1
fi

echo "[*] Initializing restoration for $MODULE_NAME from $BACKUP_DIR..."

if [[ ! -d "$BACKUP_DIR" ]]; then
    echo "[*] Backup directory $BACKUP_DIR not found. Ensuring GUI services are active..."
    systemctl unmask display-manager.service 2>/dev/null || true
    systemctl start display-manager.service 2>/dev/null || true
    systemctl start gdm3 2>/dev/null || systemctl start lightdm 2>/dev/null || systemctl start sddm 2>/dev/null || true
    exit 0
fi

# -----------------------------------------------------------------------------
# 1. KILL DUMMY TEST PROCESSES & CLEAN SYSTEMD TEST UNITS
# -----------------------------------------------------------------------------
echo "[*] Cleaning up test listeners and services..."

# Clean up test listener service
if [[ -f "/etc/systemd/system/beetle_test_listener.service" ]]; then
    systemctl stop beetle_test_listener.service 2>/dev/null || true
    systemctl disable beetle_test_listener.service 2>/dev/null || true
    rm -f /etc/systemd/system/beetle_test_listener.service 2>/dev/null || true
    systemctl daemon-reload 2>/dev/null || true
fi
pkill -f "python3 -m http.server 9999" 2>/dev/null || true

# Clean up test chrony unit if it was created as a test artifact
if [[ -f "$BACKUP_DIR/test_chrony_unit.txt" ]]; then
    test_chrony_file=$(cat "$BACKUP_DIR/test_chrony_unit.txt")
    systemctl stop chrony.service 2>/dev/null || true
    systemctl disable chrony.service 2>/dev/null || true
    systemctl unmask chrony.service 2>/dev/null || true
    rm -f "$test_chrony_file" 2>/dev/null || true
    systemctl daemon-reload 2>/dev/null || true
fi

# Kill dummy chronyd background process
if [[ -f "$BACKUP_DIR/dummy_chronyd.pid" ]]; then
    kill -9 "$(cat "$BACKUP_DIR/dummy_chronyd.pid")" 2>/dev/null || true
fi
pkill -f "exec -a chronyd" 2>/dev/null || true

# -----------------------------------------------------------------------------
# 2. RESTORE FILES, DIRECTORIES & PERMISSIONS
# -----------------------------------------------------------------------------
echo "[*] Restoring files, directories, and metadata..."

# Remove files that did not exist before testing
if [[ -f "$BACKUP_DIR/nonexistent_files.txt" ]]; then
    while IFS= read -r f; do
        [[ -n "$f" && -f "$f" ]] && rm -f "$f" 2>/dev/null || true
    done < "$BACKUP_DIR/nonexistent_files.txt"
fi

# Restore backed up file contents and metadata
for meta_file in "$BACKUP_DIR"/*.meta; do
    [[ -f "$meta_file" ]] || continue
    base_name=$(basename "$meta_file" .meta)
    
    # Check if this is a directory backup (.tar.gz) or single file
    if [[ -f "$BACKUP_DIR/${base_name}.tar.gz" ]]; then
        path_file="$BACKUP_DIR/${base_name}.path"
        if [[ -f "$path_file" ]]; then
            target_dir=$(cat "$path_file")
            rm -rf "$target_dir" 2>/dev/null || true
            tar -xzf "$BACKUP_DIR/${base_name}.tar.gz" -C / 2>/dev/null || true
            read -r _ mode owner group < "$meta_file"
            if [[ -d "$target_dir" ]]; then
                chmod "$mode" "$target_dir" 2>/dev/null || true
                chown "${owner}:${group}" "$target_dir" 2>/dev/null || true
            fi
        fi
    elif [[ -f "$BACKUP_DIR/$base_name" ]]; then
        path_file="$BACKUP_DIR/${base_name}.path"
        if [[ -f "$path_file" ]]; then
            target_file=$(cat "$path_file")
            cp -a "$BACKUP_DIR/$base_name" "$target_file" 2>/dev/null || true
            read -r _ mode owner group < "$meta_file"
            if [[ -e "$target_file" ]]; then
                chmod "$mode" "$target_file" 2>/dev/null || true
                chown "${owner}:${group}" "$target_file" 2>/dev/null || true
            fi
        fi
    fi
done

# Remove directories that did not exist before testing
if [[ -f "$BACKUP_DIR/nonexistent_dirs.txt" ]]; then
    while IFS= read -r d; do
        [[ -n "$d" && -d "$d" ]] && rm -rf "$d" 2>/dev/null || true
    done < "$BACKUP_DIR/nonexistent_dirs.txt"
fi

# -----------------------------------------------------------------------------
# 3. RESTORE SYSTEMD SERVICES
# -----------------------------------------------------------------------------
echo "[*] Restoring systemd services to original states..."
if [[ -f "$BACKUP_DIR/services.status" ]]; then
    while read -r svc enabled active; do
        [[ -z "$svc" ]] && continue
        case "$enabled" in
            enabled)
                systemctl unmask "$svc" 2>/dev/null || true
                systemctl enable "$svc" 2>/dev/null || true
                ;;
            disabled)
                systemctl unmask "$svc" 2>/dev/null || true
                systemctl disable "$svc" 2>/dev/null || true
                ;;
            masked)
                systemctl mask "$svc" 2>/dev/null || true
                ;;
        esac

        case "$active" in
            active)
                systemctl start "$svc" 2>/dev/null || true
                ;;
            inactive)
                systemctl stop "$svc" 2>/dev/null || true
                ;;
        esac
    done < "$BACKUP_DIR/services.status"
fi

# Always ensure GUI display-manager is unmasked and started
systemctl unmask display-manager.service 2>/dev/null || true
systemctl enable display-manager.service 2>/dev/null || true
systemctl start display-manager.service 2>/dev/null || true
systemctl start gdm3 2>/dev/null || systemctl start lightdm 2>/dev/null || systemctl start sddm 2>/dev/null || true

# -----------------------------------------------------------------------------
# 4. RESTORE SYSCTL PARAMETERS & KERNEL MODULES
# -----------------------------------------------------------------------------
echo "[*] Restoring kernel parameters and modprobe configurations..."
if [[ -f "$BACKUP_DIR/sysctl.status" ]]; then
    while IFS=' = ' read -r key val; do
        [[ -n "$key" && -n "$val" ]] && sysctl -w "$key=$val" 2>/dev/null || true
    done < "$BACKUP_DIR/sysctl.status"
fi

if [[ -f "$BACKUP_DIR/modprobe.tar.gz" ]]; then
    tar -xzf "$BACKUP_DIR/modprobe.tar.gz" -C / 2>/dev/null || true
fi

# -----------------------------------------------------------------------------
# 5. RESTORE FIREWALL RULES
# -----------------------------------------------------------------------------
echo "[*] Restoring firewall rules if modified..."
if [[ -f "$BACKUP_DIR/iptables.rules" ]] && command -v iptables-restore &>/dev/null; then
    iptables-restore < "$BACKUP_DIR/iptables.rules" 2>/dev/null || true
fi
if [[ -f "$BACKUP_DIR/ip6tables.rules" ]] && command -v ip6tables-restore &>/dev/null; then
    ip6tables-restore < "$BACKUP_DIR/ip6tables.rules" 2>/dev/null || true
fi
if [[ -f "$BACKUP_DIR/nftables.rules" ]] && command -v nft &>/dev/null; then
    nft -f "$BACKUP_DIR/nftables.rules" 2>/dev/null || true
fi

# -----------------------------------------------------------------------------
# 6. RESTORE DPKG RAM STORE CACHE
# -----------------------------------------------------------------------------
echo "[*] Refreshing DPKG RAM store..."
if [[ -f "$LIB_DIR/ram_store.sh" ]]; then
    source "$LIB_DIR/ram_store.sh" 2>/dev/null || true
    load_dpkg 2>/dev/null || true
fi

# -----------------------------------------------------------------------------
# 7. CLEAN UP TEMPORARY ARTIFACTS
# -----------------------------------------------------------------------------
echo "[*] Cleaning up temporary test artifacts..."
rm -rf /tmp/beetle_services_bin 2>/dev/null || true
rm -rf "$BACKUP_DIR"

echo "[+] State restoration complete for $MODULE_NAME. All pre-test settings restored."
exit 0
