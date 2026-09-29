#!/usr/bin/env bash
# restore.sh - Restores all network settings from /tmp/beetle_network_backup

set -e

BACKUP_DIR="/tmp/beetle_network_backup"

if [ ! -d "$BACKUP_DIR" ]; then
    echo "No backup found at $BACKUP_DIR — nothing to restore."
    exit 0
fi

echo "=== Restoring network state ==="

# --- 1. Restore sysctl runtime values ---
if [ -f "$BACKUP_DIR/sysctl_backup.conf" ]; then
    while IFS='=' read -r param val; do
        [ -z "$param" ] && continue
        sysctl -w "${param}=${val}" 2>/dev/null || true
    done < "$BACKUP_DIR/sysctl_backup.conf"
fi

# --- 2. Restore sysctl config files ---
for backup_file in "$BACKUP_DIR"/_etc_sysctl.d_*.meta; do
    [ -f "$backup_file" ] || continue
    base=$(basename "$backup_file" .meta)
    target_file=$(echo "$base" | tr '_' '/')
    # Fix leading slash: _etc -> /etc
    target_file="/${target_file#/}"
    if [ -f "$BACKUP_DIR/$base" ]; then
        cp -a "$BACKUP_DIR/$base" "$target_file"
        read -r mode owner group < "$backup_file"
        chmod "$mode" "$target_file" 2>/dev/null || true
        chown "${owner}:${group}" "$target_file" 2>/dev/null || true
    fi
done

# Apply restored sysctl files
sysctl --system 2>/dev/null || true

# --- 3. Restore kernel module configs ---
for mod in dccp tipc rds sctp; do
    if [ -f "$BACKUP_DIR/modprobe_${mod}.conf" ]; then
        cp -a "$BACKUP_DIR/modprobe_${mod}.conf" "/etc/modprobe.d/${mod}.conf"
    fi
    # Restore module load state (unload if it wasn't loaded before)
    if [ -f "$BACKUP_DIR/lsmod_${mod}" ]; then
        orig_state=$(cat "$BACKUP_DIR/lsmod_${mod}")
        if [ "$orig_state" == "not_loaded" ]; then
            modprobe -r "$mod" 2>/dev/null || true
        fi
    fi
done

# --- 4. Restore bluetooth service state ---
if [ -f "$BACKUP_DIR/bluetooth.enabled" ]; then
    en_state=$(cat "$BACKUP_DIR/bluetooth.enabled")
    if [ "$en_state" == "enabled" ]; then
        systemctl enable bluetooth.service 2>/dev/null || true
    else
        systemctl disable bluetooth.service 2>/dev/null || true
    fi
fi

if [ -f "$BACKUP_DIR/bluetooth.active" ]; then
    act_state=$(cat "$BACKUP_DIR/bluetooth.active")
    if [ "$act_state" == "active" ]; then
        systemctl start bluetooth.service 2>/dev/null || true
    else
        systemctl stop bluetooth.service 2>/dev/null || true
    fi
fi

# --- 5. Restore wireless state ---
if [ -f "$BACKUP_DIR/wifi_radio" ] && command -v nmcli &>/dev/null; then
    orig=$(cat "$BACKUP_DIR/wifi_radio")
    if [ "$orig" == "disabled" ]; then
        nmcli radio wifi off 2>/dev/null || true
    fi
fi

# --- 6. Restore bluez package state ---
if [ -f "$BACKUP_DIR/pkg_bluez.status" ]; then
    orig=$(cat "$BACKUP_DIR/pkg_bluez.status")
    if [[ "$orig" == "not-installed" || "$orig" != *"install ok installed"* ]]; then
        apt-get remove -y -q bluez 2>/dev/null || true
    fi
fi

rm -rf "$BACKUP_DIR"
echo "Restore completed successfully for network module."
