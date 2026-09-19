#!/usr/bin/env bash
# restore.sh - Restores all initial_setup settings from /tmp/beetle_initial_setup_backup

set -e

BACKUP_DIR="/tmp/beetle_initial_setup_backup"

if [ ! -d "$BACKUP_DIR" ]; then
    echo "No backup found at $BACKUP_DIR — nothing to restore."
    exit 0
fi

echo "=== Restoring initial_setup state ==="

export DEBIAN_FRONTEND=noninteractive

# ── 1. Restore Sysctl Runtime Values ──
if [ -f "$BACKUP_DIR/sysctl_randomize_va_space.val" ]; then
    val=$(cat "$BACKUP_DIR/sysctl_randomize_va_space.val")
    [ -n "$val" ] && sysctl -w "kernel.randomize_va_space=$val" 2>/dev/null || true
fi

if [ -f "$BACKUP_DIR/sysctl_suid_dumpable.val" ]; then
    val=$(cat "$BACKUP_DIR/sysctl_suid_dumpable.val")
    [ -n "$val" ] && sysctl -w "fs.suid_dumpable=$val" 2>/dev/null || true
fi

if [ -f "$BACKUP_DIR/sysctl_ptrace_scope.val" ]; then
    val=$(cat "$BACKUP_DIR/sysctl_ptrace_scope.val")
    [ -n "$val" ] && sysctl -w "kernel.yama.ptrace_scope=$val" 2>/dev/null || true
fi

# ── 2. Restore Systemd Services Status ──
SERVICES=("apport.service" "gdm3.service" "gdm.service" "apparmor.service")
for svc in "${SERVICES[@]}"; do
    safe_svc=$(echo "$svc" | tr '.' '_')
    if [ -f "$BACKUP_DIR/${safe_svc}.enabled" ]; then
        en=$(cat "$BACKUP_DIR/${safe_svc}.enabled")
        [ "$en" == "enabled" ]  && systemctl enable  "$svc" 2>/dev/null || true
        [ "$en" == "disabled" ] && systemctl disable "$svc" 2>/dev/null || true
    fi
    if [ -f "$BACKUP_DIR/${safe_svc}.active" ]; then
        act=$(cat "$BACKUP_DIR/${safe_svc}.active")
        [ "$act" == "active" ]   && systemctl start "$svc" 2>/dev/null || true
        [ "$act" == "inactive" ] && systemctl stop  "$svc" 2>/dev/null || true
    fi
done

# ── 3. Restore Directory Backups ──
if [ -d "$BACKUP_DIR/dconf_gdm.d_dir" ]; then
    rm -rf /etc/dconf/db/gdm.d 2>/dev/null || true
    cp -a "$BACKUP_DIR/dconf_gdm.d_dir" /etc/dconf/db/gdm.d 2>/dev/null || true
fi

if [ -d "$BACKUP_DIR/modprobe.d_dir" ]; then
    rm -rf /etc/modprobe.d 2>/dev/null || true
    cp -a "$BACKUP_DIR/modprobe.d_dir" /etc/modprobe.d 2>/dev/null || true
fi

if [ -d "$BACKUP_DIR/sources.list.d_dir" ]; then
    rm -rf /etc/apt/sources.list.d 2>/dev/null || true
    cp -a "$BACKUP_DIR/sources.list.d_dir" /etc/apt/sources.list.d 2>/dev/null || true
fi

# ── 4. Restore File Backups and Permissions Metadata ──
for backup_file in "$BACKUP_DIR"/*; do
    [ -f "$backup_file" ] || continue
    case "$backup_file" in
        *.meta|*.enabled|*.active|*.val|*.status|*.out|*.rules) continue ;;
    esac
    base_name=$(basename "$backup_file")
    target_file=$(echo "$base_name" | tr '_' '/')
    cp -a "$backup_file" "$target_file" 2>/dev/null || true
done

for meta_file in "$BACKUP_DIR"/*.meta; do
    [ -f "$meta_file" ] || continue
    base_name=$(basename "$meta_file" .meta)
    target_file=$(echo "$base_name" | tr '_' '/')
    if [ -e "$target_file" ]; then
        read -r mode owner group < "$meta_file"
        chmod "$mode" "$target_file" 2>/dev/null || true
        chown "${owner}:${group}" "$target_file" 2>/dev/null || true
    fi
done

# ── 5. Restore Package Installation State ──
for status_file in "$BACKUP_DIR"/pkg_*.status; do
    [ -f "$status_file" ] || continue
    pkg=$(basename "$status_file" .status | sed 's/^pkg_//')
    orig=$(cat "$status_file")
    if [[ "$orig" != *"install ok installed"* ]]; then
        systemctl stop    "$pkg" 2>/dev/null || true
        systemctl disable "$pkg" 2>/dev/null || true
        apt-get remove -y -q --purge "$pkg" </dev/null >/dev/null 2>&1 || true
    fi
done

# ── 6. Clean up temporary files ──
rm -rf "$BACKUP_DIR"
echo "Restore completed successfully for initial_setup module."
