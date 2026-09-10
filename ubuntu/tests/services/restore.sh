#!/usr/bin/env bash
# restore.sh - Restores all services settings from /tmp/beetle_services_backup

set -e

BACKUP_DIR="/tmp/beetle_services_backup"

if [ ! -d "$BACKUP_DIR" ]; then
    echo "No backup found at $BACKUP_DIR — nothing to restore."
    exit 0
fi

echo "=== Restoring services state ==="

# --- 1. Restore cron/at file permissions ---
CRON_FILES=(
    "/etc/crontab"
    "/etc/cron.hourly"
    "/etc/cron.daily"
    "/etc/cron.weekly"
    "/etc/cron.monthly"
    "/etc/cron.d"
    "/etc/cron.allow"
    "/etc/cron.deny"
    "/etc/at.allow"
    "/etc/at.deny"
)
for f in "${CRON_FILES[@]}"; do
    safe=$(echo "$f" | tr '/' '_')
    if [ -f "$BACKUP_DIR/${safe}.meta" ]; then
        # Restore content if backed up
        if [ -e "$BACKUP_DIR/${safe}" ]; then
            cp -a "$BACKUP_DIR/${safe}" "$f" 2>/dev/null || true
        fi
        # Restore permissions
        read -r mode owner group < "$BACKUP_DIR/${safe}.meta"
        [ -e "$f" ] && chmod "$mode" "$f" 2>/dev/null || true
        [ -e "$f" ] && chown "${owner}:${group}" "$f" 2>/dev/null || true
    fi
done

# --- 2. Restore cron service state ---
if [ -f "$BACKUP_DIR/cron.enabled" ]; then
    en=$(cat "$BACKUP_DIR/cron.enabled")
    [ "$en" == "enabled" ] && systemctl enable cron.service 2>/dev/null || true
fi
if [ -f "$BACKUP_DIR/cron.active" ]; then
    act=$(cat "$BACKUP_DIR/cron.active")
    if [ "$act" == "active" ]; then
        systemctl start cron.service 2>/dev/null || true
    fi
fi

# --- 3. Restore time sync service states ---
for svc in chrony.service systemd-timesyncd.service; do
    safe=$(echo "$svc" | tr '.' '_')
    if [ -f "$BACKUP_DIR/${safe}.enabled" ]; then
        en=$(cat "$BACKUP_DIR/${safe}.enabled")
        [ "$en" == "enabled" ] && systemctl enable "$svc" 2>/dev/null || true
        [ "$en" == "disabled" ] && systemctl disable "$svc" 2>/dev/null || true
    fi
    if [ -f "$BACKUP_DIR/${safe}.active" ]; then
        act=$(cat "$BACKUP_DIR/${safe}.active")
        [ "$act" == "active" ] && systemctl start "$svc" 2>/dev/null || true
        [ "$act" == "inactive" ] && systemctl stop "$svc" 2>/dev/null || true
    fi
done

# --- 4. Remove any restricted packages that were installed during test ---
# Only remove telnet/ftp if they were not originally installed
for pkg in telnet ftp; do
    orig=$(cat "$BACKUP_DIR/pkg_${pkg}.status" 2>/dev/null || echo "not-installed")
    if [[ "$orig" == "not-installed" || "$orig" != *"install ok installed"* ]]; then
        apt-get remove -y -q "$pkg" 2>/dev/null || true
    fi
done

rm -rf "$BACKUP_DIR"
echo "Restore completed successfully for services module."
