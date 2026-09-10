#!/usr/bin/env bash
# unsecure.sh - Unsecures all services module settings checked by Beetle audit/harden scripts.
# Backup store: /tmp/beetle_services_backup

set -e

BACKUP_DIR="/tmp/beetle_services_backup"
mkdir -p "$BACKUP_DIR"

echo "=== Backing up current services state ==="

# --- 1. Cron/At file permissions and access control files ---
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
    if [ -e "$f" ]; then
        safe=$(echo "$f" | tr '/' '_')
        cp -a "$f" "$BACKUP_DIR/${safe}" 2>/dev/null || true
        stat -c "%a %U %G" "$f" > "$BACKUP_DIR/${safe}.meta" 2>/dev/null || true
    fi
done

# --- 2. Service installation & active/enabled state ---
# Server services to restrict (should NOT be installed/running)
SERVER_PKGS=(
    autofs avahi-daemon isc-dhcp-server udhcpd kea
    bind9 unbound powerdns dnsmasq vsftpd proftpd pure-ftpd
    slapd ldap-utils dovecot-imapd dovecot-pop3d courier-imap cyrus-imapd
    nfs-kernel-server nfs-common nis yp-tools cups cups-browsed rpcbind
    rsync snmpd snmp tftpd-hpa atftpd squid tinyproxy privoxy
    apache2 xserver-xorg x11-common xinetd exim4 sendmail
)
for pkg in "${SERVER_PKGS[@]}"; do
    dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null > "$BACKUP_DIR/pkg_${pkg}.status" || echo "not-installed" > "$BACKUP_DIR/pkg_${pkg}.status"
done

# Client services to restrict
CLIENT_PKGS=(nis rsh-client talk telnet inetutils-telnet ldap-utils ftp tnftp)
for pkg in "${CLIENT_PKGS[@]}"; do
    dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null > "$BACKUP_DIR/pkg_${pkg}.status" || echo "not-installed" > "$BACKUP_DIR/pkg_${pkg}.status"
done

# Cron & At daemon states
systemctl is-enabled cron.service 2>/dev/null > "$BACKUP_DIR/cron.enabled" || echo "disabled" > "$BACKUP_DIR/cron.enabled"
systemctl is-active cron.service 2>/dev/null > "$BACKUP_DIR/cron.active" || echo "inactive" > "$BACKUP_DIR/cron.active"

# Time sync daemon states (chrony / systemd-timesyncd)
for svc in chrony.service systemd-timesyncd.service; do
    safe=$(echo "$svc" | tr '.' '_')
    systemctl is-enabled "$svc" 2>/dev/null > "$BACKUP_DIR/${safe}.enabled" || echo "disabled" > "$BACKUP_DIR/${safe}.enabled"
    systemctl is-active "$svc" 2>/dev/null > "$BACKUP_DIR/${safe}.active" || echo "inactive" > "$BACKUP_DIR/${safe}.active"
done

echo "=== Unsecuring services settings ==="

# --- 1. Cron/At: set insecure permissions ---
for f in /etc/crontab /etc/cron.hourly /etc/cron.daily /etc/cron.weekly /etc/cron.monthly /etc/cron.d; do
    [ -e "$f" ] && chmod 777 "$f" 2>/dev/null || true
done

# Remove cron.allow so only cron.deny controls access (insecure config)
rm -f /etc/cron.allow 2>/dev/null || true
# Add cron.deny with no entries (everyone allowed — insecure)
> /etc/cron.deny

# At access: remove at.allow (insecure — everyone allowed)
rm -f /etc/at.allow 2>/dev/null || true
> /etc/at.deny

# --- 2. Disable cron daemon (audit expects it enabled/active) ---
systemctl stop cron.service 2>/dev/null || true
systemctl disable cron.service 2>/dev/null || true

# --- 3. Install restricted client packages if possible (to simulate presence)
# We only install if they happen to be available — don't force installation
# (audit checks for package presence via dpkg; unsecure means they ARE present)
# Attempt to install a few lightweight restricted client packages
for pkg in telnet ftp; do
    if ! dpkg -l "$pkg" &>/dev/null; then
        apt-get install -y -q "$pkg" 2>/dev/null || true
    fi
done

echo "Unsecure completed successfully for services module."
