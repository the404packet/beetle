#!/usr/bin/env bash
# restore.sh - Restores settings from /tmp/beetle_logging_and_auditing_backup

set -e

BACKUP_DIR="/tmp/beetle_logging_and_auditing_backup"

export DEBIAN_FRONTEND=noninteractive

if [ ! -d "$BACKUP_DIR" ]; then
    echo "No backup found at $BACKUP_DIR — nothing to restore."
    exit 0
fi

echo "=== Restoring backed up logging_and_auditing state ==="

# 1. Restore journald configs
if [ -f "$BACKUP_DIR/journald.conf" ]; then
    cp -a "$BACKUP_DIR/journald.conf" /etc/systemd/journald.conf
    if [ -f "$BACKUP_DIR/journald.conf.meta" ]; then
        read -r mode owner group < "$BACKUP_DIR/journald.conf.meta"
        chmod "$mode" /etc/systemd/journald.conf 2>/dev/null || true
        chown "${owner}:${group}" /etc/systemd/journald.conf 2>/dev/null || true
    fi
fi

if [ -d "$BACKUP_DIR/journald.conf.d_dir" ]; then
    rm -rf /etc/systemd/journald.conf.d
    cp -a "$BACKUP_DIR/journald.conf.d_dir" /etc/systemd/journald.conf.d
fi

# 2. Restore rsyslog configs
if [ -f "$BACKUP_DIR/rsyslog.conf" ]; then
    cp -a "$BACKUP_DIR/rsyslog.conf" /etc/rsyslog.conf
    if [ -f "$BACKUP_DIR/rsyslog.conf.meta" ]; then
        read -r mode owner group < "$BACKUP_DIR/rsyslog.conf.meta"
        chmod "$mode" /etc/rsyslog.conf 2>/dev/null || true
        chown "${owner}:${group}" /etc/rsyslog.conf 2>/dev/null || true
    fi
fi

if [ -d "$BACKUP_DIR/rsyslog.d_dir" ]; then
    rm -rf /etc/rsyslog.d
    cp -a "$BACKUP_DIR/rsyslog.d_dir" /etc/rsyslog.d
fi

# 3. Restore /var/log permissions
for meta in "$BACKUP_DIR"/log_*.meta; do
    [ -f "$meta" ] || continue
    safe_p=$(basename "$meta" .meta)
    safe_p="${safe_p#log_}"
    target_path=$(echo "$safe_p" | tr '_' '/')
    if [ -e "$target_path" ]; then
        read -r mode owner group < "$meta"
        chmod "$mode" "$target_path" 2>/dev/null || true
        chown "${owner}:${group}" "$target_path" 2>/dev/null || true
    fi
done

# 4. Restore auditd configs, rules, GRUB, AIDE
if [ -f "$BACKUP_DIR/auditd.conf" ]; then
    mkdir -p /etc/audit
    cp -a "$BACKUP_DIR/auditd.conf" /etc/audit/auditd.conf
    if [ -f "$BACKUP_DIR/auditd.conf.meta" ]; then
        read -r mode owner group < "$BACKUP_DIR/auditd.conf.meta"
        chmod "$mode" /etc/audit/auditd.conf 2>/dev/null || true
        chown "${owner}:${group}" /etc/audit/auditd.conf 2>/dev/null || true
    fi
fi

if [ -d "$BACKUP_DIR/rules.d_dir" ]; then
    rm -rf /etc/audit/rules.d
    mkdir -p /etc/audit
    cp -a "$BACKUP_DIR/rules.d_dir" /etc/audit/rules.d
fi

if [ -f "$BACKUP_DIR/grub" ]; then
    cp -a "$BACKUP_DIR/grub" /etc/default/grub
fi

if [ -f "$BACKUP_DIR/aide.conf" ]; then
    mkdir -p /etc/aide
    cp -a "$BACKUP_DIR/aide.conf" /etc/aide/aide.conf
fi

# 5. Reinstall packages that were originally present
for status_file in "$BACKUP_DIR"/pkg_*.status; do
    [ -f "$status_file" ] || continue
    pkg=$(basename "$status_file" .status | sed 's/^pkg_//')
    orig=$(cat "$status_file")
    if [[ "$orig" == *"install ok installed"* ]]; then
        if ! dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "install ok installed"; then
            apt-get install -y -q "$pkg" </dev/null >/dev/null 2>&1 || true
        fi
    fi
done

# 6. Restore service states
if [ -f "$BACKUP_DIR/auditd.enabled" ]; then
    en_state=$(cat "$BACKUP_DIR/auditd.enabled")
    [ "$en_state" == "enabled" ]  && systemctl enable  auditd 2>/dev/null || true
    [ "$en_state" == "disabled" ] && systemctl disable auditd 2>/dev/null || true
fi

if [ -f "$BACKUP_DIR/auditd.active" ]; then
    act_state=$(cat "$BACKUP_DIR/auditd.active")
    [ "$act_state" == "active" ]   && systemctl start auditd 2>/dev/null || true
    [ "$act_state" == "inactive" ] && systemctl stop  auditd 2>/dev/null || true
fi

if [ -f "$BACKUP_DIR/rsyslog.active" ]; then
    act_state=$(cat "$BACKUP_DIR/rsyslog.active")
    [ "$act_state" == "active" ] && systemctl restart rsyslog 2>/dev/null || true
fi

if [ -f "$BACKUP_DIR/journald.active" ]; then
    act_state=$(cat "$BACKUP_DIR/journald.active")
    [ "$act_state" == "active" ] && systemctl restart systemd-journald 2>/dev/null || true
fi

if [ -f "$BACKUP_DIR/aide.timer.enabled" ]; then
    en_state=$(cat "$BACKUP_DIR/aide.timer.enabled")
    [ "$en_state" == "enabled" ] && systemctl enable --now dailyaidecheck.timer 2>/dev/null || true
fi

# 7. Safety check — verify basic tools still exist
for tool in sed awk grep find sudo; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "WARNING: $tool is missing after restore — reinstalling"
        apt-get install --reinstall -y "$tool" </dev/null >/dev/null 2>&1 || true
    fi
done

rm -rf "$BACKUP_DIR"
echo "Restore completed successfully for logging_and_auditing."