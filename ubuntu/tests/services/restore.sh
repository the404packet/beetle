#!/usr/bin/env bash
# restore.sh - Restores all services settings from /tmp/beetle_services_backup

set -e

BACKUP_DIR="/tmp/beetle_services_backup"

if [ ! -d "$BACKUP_DIR" ]; then
    echo "No backup found at $BACKUP_DIR — nothing to restore."
    exit 0
fi

echo "=== Restoring services state ==="

export DEBIAN_FRONTEND=noninteractive

# ── 1. Restore cron/at file permissions ──
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
        if [ -e "$BACKUP_DIR/${safe}" ]; then
            cp -a "$BACKUP_DIR/${safe}" "$f" 2>/dev/null || true
        fi
        read -r mode owner group < "$BACKUP_DIR/${safe}.meta"
        [ -e "$f" ] && chmod "$mode" "$f" 2>/dev/null || true
        [ -e "$f" ] && chown "${owner}:${group}" "$f" 2>/dev/null || true
    fi
done

# ── 2. Restore cron service state ──
if [ -f "$BACKUP_DIR/cron.enabled" ]; then
    en=$(cat "$BACKUP_DIR/cron.enabled")
    [ "$en" == "enabled" ]  && systemctl enable  cron.service 2>/dev/null || true
    [ "$en" == "disabled" ] && systemctl disable cron.service 2>/dev/null || true
fi
if [ -f "$BACKUP_DIR/cron.active" ]; then
    act=$(cat "$BACKUP_DIR/cron.active")
    [ "$act" == "active" ]   && systemctl start cron.service 2>/dev/null || true
    [ "$act" == "inactive" ] && systemctl stop  cron.service 2>/dev/null || true
fi

# ── 3. Restore time sync service states ──
for svc in chrony.service systemd-timesyncd.service; do
    safe=$(echo "$svc" | tr '.' '_')
    if [ -f "$BACKUP_DIR/${safe}.enabled" ]; then
        en=$(cat "$BACKUP_DIR/${safe}.enabled")
        [ "$en" == "enabled" ]  && systemctl enable  "$svc" 2>/dev/null || true
        [ "$en" == "disabled" ] && systemctl disable "$svc" 2>/dev/null || true
    fi
    if [ -f "$BACKUP_DIR/${safe}.active" ]; then
        act=$(cat "$BACKUP_DIR/${safe}.active")
        [ "$act" == "active" ]   && systemctl start "$svc" 2>/dev/null || true
        [ "$act" == "inactive" ] && systemctl stop  "$svc" 2>/dev/null || true
    fi
done

# ── 4. Remove every package that wasn't originally installed ──
# Iterates all pkg_*.status files. If the backup status was NOT "install ok
# installed", the package is uninstalled now. Catches the subset AND anything
# else that got installed along the way.
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

# ── 5. Clean up orphaned dependencies ──
apt-get autoremove -y -q </dev/null >/dev/null 2>&1 || true

rm -rf "$BACKUP_DIR"
echo "Restore completed successfully for services module."