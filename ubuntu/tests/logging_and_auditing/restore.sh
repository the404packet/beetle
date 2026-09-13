#!/usr/bin/env bash
# restore.sh - Restores settings from /tmp/beetle_logging_and_auditing_backup and cleans up test entries.

set -e

BACKUP_DIR="/tmp/beetle_logging_and_auditing_backup"

if [ -d "$BACKUP_DIR" ]; then
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

    # 4. Restore auditd configs, rules, and GRUB
    if [ -f "$BACKUP_DIR/auditd.conf" ]; then
        cp -a "$BACKUP_DIR/auditd.conf" /etc/audit/auditd.conf
        if [ -f "$BACKUP_DIR/auditd.conf.meta" ]; then
            read -r mode owner group < "$BACKUP_DIR/auditd.conf.meta"
            chmod "$mode" /etc/audit/auditd.conf 2>/dev/null || true
            chown "${owner}:${group}" /etc/audit/auditd.conf 2>/dev/null || true
        fi
    fi

    if [ -d "$BACKUP_DIR/rules.d_dir" ]; then
        rm -rf /etc/audit/rules.d
        cp -a "$BACKUP_DIR/rules.d_dir" /etc/audit/rules.d
    fi

    if [ -f "$BACKUP_DIR/grub" ]; then
        cp -a "$BACKUP_DIR/grub" /etc/default/grub
    fi

    # Restore AIDE config
    if [ -f "$BACKUP_DIR/aide.conf" ]; then
        cp -a "$BACKUP_DIR/aide.conf" /etc/aide/aide.conf
    fi

    # Restore service states (active/enabled)
    if [ -f "$BACKUP_DIR/auditd.enabled" ]; then
        en_state=$(cat "$BACKUP_DIR/auditd.enabled")
        if [ "$en_state" == "enabled" ]; then
            systemctl enable auditd 2>/dev/null || true
        fi
    fi

    if [ -f "$BACKUP_DIR/auditd.active" ]; then
        act_state=$(cat "$BACKUP_DIR/auditd.active")
        if [ "$act_state" == "active" ]; then
            systemctl start auditd 2>/dev/null || true
        fi
    fi

    if [ -f "$BACKUP_DIR/rsyslog.active" ]; then
        act_state=$(cat "$BACKUP_DIR/rsyslog.active")
        if [ "$act_state" == "active" ]; then
            systemctl restart rsyslog 2>/dev/null || true
        fi
    fi

    if [ -f "$BACKUP_DIR/journald.active" ]; then
        act_state=$(cat "$BACKUP_DIR/journald.active")
        if [ "$act_state" == "active" ]; then
            systemctl restart systemd-journald 2>/dev/null || true
        fi
    fi

    if [ -f "$BACKUP_DIR/aide.timer.enabled" ]; then
        en_state=$(cat "$BACKUP_DIR/aide.timer.enabled")
        if [ "$en_state" == "enabled" ]; then
            systemctl enable --now dailyaidecheck.timer 2>/dev/null || true
        fi
    fi

    rm -rf "$BACKUP_DIR"
fi

echo "Restore completed successfully for logging_and_auditing."
