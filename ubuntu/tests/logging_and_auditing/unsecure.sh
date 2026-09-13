#!/usr/bin/env bash
# unsecure.sh - Unsecures logging_and_auditing settings audited and hardened by Beetle.
# Backup store: /tmp/beetle_logging_and_auditing_backup

set -e

BACKUP_DIR="/tmp/beetle_logging_and_auditing_backup"
mkdir -p "$BACKUP_DIR"

echo "=== Backing up current logging_and_auditing state ==="

# 1. Systemd journald service & configs
JOURNALD_CONF="/etc/systemd/journald.conf"
if [ -f "$JOURNALD_CONF" ]; then
    cp -a "$JOURNALD_CONF" "$BACKUP_DIR/journald.conf"
    stat -c "%a %U %G" "$JOURNALD_CONF" > "$BACKUP_DIR/journald.conf.meta"
fi

if [ -d "/etc/systemd/journald.conf.d" ]; then
    cp -a "/etc/systemd/journald.conf.d" "$BACKUP_DIR/journald.conf.d_dir"
fi

# 2. Rsyslog configs
RSYSLOG_CONF="/etc/rsyslog.conf"
if [ -f "$RSYSLOG_CONF" ]; then
    cp -a "$RSYSLOG_CONF" "$BACKUP_DIR/rsyslog.conf"
    stat -c "%a %U %G" "$RSYSLOG_CONF" > "$BACKUP_DIR/rsyslog.conf.meta"
fi

if [ -d "/etc/rsyslog.d" ]; then
    cp -a "/etc/rsyslog.d" "$BACKUP_DIR/rsyslog.d_dir"
fi

# 3. Logfile permissions in /var/log
if [ -d "/var/log" ]; then
    find /var/log -maxdepth 3 -type f -o -type d 2>/dev/null | while read -r p; do
        safe_p=$(echo "$p" | tr '/' '_')
        stat -c "%a %U %G" "$p" > "$BACKUP_DIR/log_${safe_p}.meta" 2>/dev/null || true
    done
fi

# 4. Auditd configs, GRUB audit settings, rules, and binary permissions
AUDITD_CONF="/etc/audit/auditd.conf"
if [ -f "$AUDITD_CONF" ]; then
    cp -a "$AUDITD_CONF" "$BACKUP_DIR/auditd.conf"
    stat -c "%a %U %G" "$AUDITD_CONF" > "$BACKUP_DIR/auditd.conf.meta"
fi

if [ -d "/etc/audit/rules.d" ]; then
    cp -a "/etc/audit/rules.d" "$BACKUP_DIR/rules.d_dir"
fi

GRUB_CONF="/etc/default/grub"
if [ -f "$GRUB_CONF" ]; then
    cp -a "$GRUB_CONF" "$BACKUP_DIR/grub"
fi

# Backup auditd and journald service state (enabled/active)
systemctl is-enabled auditd 2>/dev/null > "$BACKUP_DIR/auditd.enabled" || echo "disabled" > "$BACKUP_DIR/auditd.enabled"
systemctl is-active auditd 2>/dev/null > "$BACKUP_DIR/auditd.active" || echo "inactive" > "$BACKUP_DIR/auditd.active"

systemctl is-enabled systemd-journald 2>/dev/null > "$BACKUP_DIR/journald.enabled" || echo "disabled" > "$BACKUP_DIR/journald.enabled"
systemctl is-active systemd-journald 2>/dev/null > "$BACKUP_DIR/journald.active" || echo "inactive" > "$BACKUP_DIR/journald.active"

systemctl is-enabled rsyslog 2>/dev/null > "$BACKUP_DIR/rsyslog.enabled" || echo "disabled" > "$BACKUP_DIR/rsyslog.enabled"
systemctl is-active rsyslog 2>/dev/null > "$BACKUP_DIR/rsyslog.active" || echo "inactive" > "$BACKUP_DIR/rsyslog.active"

# Backup AIDE timer/service if available
systemctl is-enabled dailyaidecheck.timer 2>/dev/null > "$BACKUP_DIR/aide.timer.enabled" || echo "disabled" > "$BACKUP_DIR/aide.timer.enabled"
AIDE_CONF="/etc/aide/aide.conf"
if [ -f "$AIDE_CONF" ]; then
    cp -a "$AIDE_CONF" "$BACKUP_DIR/aide.conf"
fi

echo "=== Unsecuring logging_and_auditing settings ==="

# 1. Unsecure journald parameters (Set invalid values / clear settings)
if [ -f "$JOURNALD_CONF" ]; then
    sed -i 's/^Storage=.*/Storage=none/' "$JOURNALD_CONF" || echo "Storage=none" >> "$JOURNALD_CONF"
    sed -i 's/^ForwardToSyslog=.*/ForwardToSyslog=yes/' "$JOURNALD_CONF" || echo "ForwardToSyslog=yes" >> "$JOURNALD_CONF"
    sed -i 's/^Compress=.*/Compress=no/' "$JOURNALD_CONF" || echo "Compress=no" >> "$JOURNALD_CONF"
    sed -i 's/^SystemMaxUse=.*/SystemMaxUse=0/' "$JOURNALD_CONF" || echo "SystemMaxUse=0" >> "$JOURNALD_CONF"
fi

# Remove journald drop-in configs
rm -rf /etc/systemd/journald.conf.d/* 2>/dev/null || true

# 2. Unsecure rsyslog config & permissions
if [ -f "$RSYSLOG_CONF" ]; then
    chmod 777 "$RSYSLOG_CONF"
    sed -i 's/^\$FileCreateMode.*/$FileCreateMode 0777/' "$RSYSLOG_CONF" 2>/dev/null || true
fi
rm -rf /etc/rsyslog.d/* 2>/dev/null || true

# 3. Unsecure /var/log file permissions
if [ -d "/var/log" ]; then
    chmod 777 /var/log
    find /var/log -type f -exec chmod 777 {} + 2>/dev/null || true
fi

# 4. Unsecure auditd config & GRUB parameters
if [ -f "$AUDITD_CONF" ]; then
    chmod 777 "$AUDITD_CONF"
    sed -i 's/^max_log_file_action = .*/max_log_file_action = rotate/' "$AUDITD_CONF" 2>/dev/null || true
    sed -i 's/^space_left_action = .*/space_left_action = ignore/' "$AUDITD_CONF" 2>/dev/null || true
    sed -i 's/^action_mail_acct = .*/action_mail_acct = root/' "$AUDITD_CONF" 2>/dev/null || true
    sed -i 's/^admin_space_left_action = .*/admin_space_left_action = ignore/' "$AUDITD_CONF" 2>/dev/null || true
    sed -i 's/^disk_full_action = .*/disk_full_action = ignore/' "$AUDITD_CONF" 2>/dev/null || true
    sed -i 's/^disk_error_action = .*/disk_error_action = ignore/' "$AUDITD_CONF" 2>/dev/null || true
fi

# Clear audit rules
rm -rf /etc/audit/rules.d/* 2>/dev/null || true

# Unsecure auditd tool permissions
AUDIT_TOOLS=("/sbin/auditctl" "/sbin/aureport" "/sbin/ausearch" "/sbin/autrace" "/sbin/auditd" "/sbin/augenrules")
for tool in "${AUDIT_TOOLS[@]}"; do
    if [ -f "$tool" ]; then
        chmod 777 "$tool" 2>/dev/null || true
    fi
done

# Remove audit=1 and audit_backlog_limit from GRUB config
if [ -f "$GRUB_CONF" ]; then
    sed -i 's/audit=1//g' "$GRUB_CONF"
    sed -i 's/audit_backlog_limit=[0-9]*//g' "$GRUB_CONF"
fi

# Disable AIDE timer if present
systemctl disable --now dailyaidecheck.timer 2>/dev/null || true

echo "Unsecure completed successfully for logging_and_auditing."
