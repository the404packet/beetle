#!/usr/bin/env bash
# unsecure.sh - Unsecures all services module settings checked by Beetle audit/harden scripts.
# Backup store: /tmp/beetle_services_backup

set -e

BACKUP_DIR="/tmp/beetle_services_backup"
mkdir -p "$BACKUP_DIR"

# Never let apt/debconf block on input
export DEBIAN_FRONTEND=noninteractive

# ── Representative subset of restricted packages to install ──
# Full list is ~20 packages and pulls heavy deps (bind9, apache2, samba).
# These exercise the install/remove codepath without bloating the VM.
UNSECURE_PKGS=(
    xinetd
    rpcbind
    snmpd
    tftpd-hpa
    vsftpd
    telnet
    ftp
)

# Everything the JSON marks restrict:true — used for backup tracking only
SERVER_PKGS=(
    autofs avahi-daemon isc-dhcp-server udhcpd kea
    bind9 unbound powerdns dnsmasq vsftpd proftpd pure-ftpd
    slapd ldap-utils dovecot-imapd dovecot-pop3d courier-imap cyrus-imapd
    nfs-kernel-server nfs-common nis yp-tools cups cups-browsed rpcbind
    rsync snmpd snmp tftpd-hpa atftpd squid tinyproxy privoxy
    apache2 xserver-xorg xorg x11-common xinetd exim4 sendmail
    samba-common-bin
)

CLIENT_PKGS=(nis rsh-client talk telnet inetutils-telnet ldap-utils ftp tnftp)

echo "=== Backing up current services state ==="

# ── 1. Cron/At file permissions and access control files ──
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

# ── 2. Package status snapshots ──
for pkg in "${SERVER_PKGS[@]}" "${CLIENT_PKGS[@]}"; do
    dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null > "$BACKUP_DIR/pkg_${pkg}.status" \
        || echo "not-installed" > "$BACKUP_DIR/pkg_${pkg}.status"
done

# ── 3. Service states ──
systemctl is-enabled cron.service 2>/dev/null > "$BACKUP_DIR/cron.enabled" || echo "disabled" > "$BACKUP_DIR/cron.enabled"
systemctl is-active  cron.service 2>/dev/null > "$BACKUP_DIR/cron.active"  || echo "inactive" > "$BACKUP_DIR/cron.active"

for svc in chrony.service systemd-timesyncd.service; do
    safe=$(echo "$svc" | tr '.' '_')
    systemctl is-enabled "$svc" 2>/dev/null > "$BACKUP_DIR/${safe}.enabled" || echo "disabled" > "$BACKUP_DIR/${safe}.enabled"
    systemctl is-active  "$svc" 2>/dev/null > "$BACKUP_DIR/${safe}.active"  || echo "inactive" > "$BACKUP_DIR/${safe}.active"
done

echo "=== Unsecuring services settings ==="

# ── 1. Cron/At: insecure permissions ──
for f in /etc/crontab /etc/cron.hourly /etc/cron.daily /etc/cron.weekly /etc/cron.monthly /etc/cron.d; do
    [ -e "$f" ] && chmod 777 "$f" 2>/dev/null || true
done

rm -f /etc/cron.allow 2>/dev/null || true
> /etc/cron.deny

rm -f /etc/at.allow 2>/dev/null || true
> /etc/at.deny

# ── 2. Disable cron daemon ──
systemctl stop    cron.service 2>/dev/null || true
systemctl disable cron.service 2>/dev/null || true

# ── 2b. Break time_sync state so audits report NOT HARDENED ──
for svc in chrony.service systemd-timesyncd.service; do
    systemctl stop    "$svc" 2>/dev/null || true
    systemctl disable "$svc" 2>/dev/null || true
done

# ── 3. Install the restricted-package subset ──
for pkg in "${UNSECURE_PKGS[@]}"; do
    if ! dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "install ok installed"; then
        apt-get install -y -q "$pkg" </dev/null >/dev/null 2>&1 || true
    fi
    case "$pkg" in
        xinetd)    systemctl enable --now xinetd.service    2>/dev/null || true ;;
        rpcbind)   systemctl enable --now rpcbind.service   2>/dev/null || true
                   systemctl enable --now rpcbind.socket    2>/dev/null || true ;;
        snmpd)     systemctl enable --now snmpd.service     2>/dev/null || true ;;
        tftpd-hpa) systemctl enable --now tftpd-hpa.service 2>/dev/null || true ;;
        vsftpd)    systemctl enable --now vsftpd.service    2>/dev/null || true ;;
    esac
done

echo "Unsecure completed successfully for services module."
