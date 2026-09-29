#!/usr/bin/env bash
# =============================================================================
# ubuntu/tests/services/unsecure.sh
# Automated Test Suite: Initial State Backup and Unsecuring for services module
# =============================================================================

set -e

BACKUP_DIR="/tmp/beetle_services_backup"
MODULE_NAME="services"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BEETLE_SHELL_ROOT="$(cd "$SCRIPT_DIR/../../beetle_shell" && pwd)"
CONFIG_DIR="$(cd "$SCRIPT_DIR/../../config" && pwd)"
SERVICES_JSON="$CONFIG_DIR/services.json"

# Root check
if [[ "$EUID" -ne 0 ]]; then
    echo "[!] unsecure.sh must be run as root"
    exit 1
fi

echo "[*] Initializing pre-test backup for $MODULE_NAME in $BACKUP_DIR..."

# -----------------------------------------------------------------------------
# STEP 1: CAPTURE INITIAL STATE SNAPSHOT
# -----------------------------------------------------------------------------
if [[ -d "$BACKUP_DIR" ]]; then
    echo "[*] Backup directory $BACKUP_DIR already exists; preserving existing pre-test snapshot."
else
    mkdir -p "$BACKUP_DIR"
    chmod 700 "$BACKUP_DIR"

    # 1. System File Permissions & Content
    echo "[*] Backing up system file permissions and content..."
    FILES=(
        "/etc/crontab"
        "/etc/cron.allow"
        "/etc/cron.deny"
        "/etc/at.allow"
        "/etc/at.deny"
        "/etc/systemd/timesyncd.conf"
        "/etc/chrony/chrony.conf"
        "/etc/postfix/main.cf"
    )

    > "$BACKUP_DIR/file_perms.txt"
    > "$BACKUP_DIR/nonexistent_files.txt"

    for f in "${FILES[@]}"; do
        if [[ -f "$f" ]]; then
            safe_name=$(echo "$f" | tr '/' '_')
            cp -a "$f" "$BACKUP_DIR/$safe_name"
            stat_meta=$(stat -c "%a %U %G" "$f" 2>/dev/null || true)
            echo "$safe_name $stat_meta" > "$BACKUP_DIR/${safe_name}.meta"
            echo "$f" > "$BACKUP_DIR/${safe_name}.path"
            echo "$f $stat_meta" >> "$BACKUP_DIR/file_perms.txt"
        else
            echo "$f" >> "$BACKUP_DIR/nonexistent_files.txt"
        fi
    done

    # Backup Directories (cron dirs, timesyncd drop-ins, chrony sources)
    DIRS=(
        "/etc/cron.hourly"
        "/etc/cron.daily"
        "/etc/cron.weekly"
        "/etc/cron.monthly"
        "/etc/cron.d"
        "/etc/systemd/timesyncd.conf.d"
        "/etc/chrony/sources.d"
    )

    > "$BACKUP_DIR/dir_perms.txt"
    > "$BACKUP_DIR/nonexistent_dirs.txt"

    for d in "${DIRS[@]}"; do
        if [[ -d "$d" ]]; then
            safe_d=$(echo "$d" | tr '/' '_')
            tar -czf "$BACKUP_DIR/${safe_d}_dir.tar.gz" -C / "${d#/}" 2>/dev/null || true
            stat_meta=$(stat -c "%a %U %G" "$d" 2>/dev/null || true)
            echo "$safe_d $stat_meta" > "$BACKUP_DIR/${safe_d}_dir.meta"
            echo "$d" > "$BACKUP_DIR/${safe_d}_dir.path"
            echo "$d $stat_meta" >> "$BACKUP_DIR/dir_perms.txt"
        else
            echo "$d" >> "$BACKUP_DIR/nonexistent_dirs.txt"
        fi
    done

    # 2. Systemd Services Status & Package States
    echo "[*] Backing up systemd services and package states..."
    SERVICES=(
        "cron"
        "atd"
        "systemd-timesyncd"
        "chrony"
        "autofs"
        "avahi-daemon"
        "isc-dhcp-server"
        "isc-dhcp-server6"
        "udhcpd"
        "kea-dhcp4"
        "kea-dhcp6"
        "bind9"
        "named"
        "unbound"
        "pdns"
        "dnsmasq"
        "vsftpd"
        "proftpd"
        "pure-ftpd"
        "slapd"
        "dovecot"
        "courier-imap"
        "cyrus-imapd"
        "nfs-server"
        "nfs-kernel-server"
        "nfs-common"
        "nis"
        "ypbind"
        "cups"
        "cups-browsed"
        "rpcbind"
        "rsync"
        "smbd"
        "nmbd"
        "winbind"
        "snmpd"
        "tftpd-hpa"
        "atftpd"
        "squid"
        "tinyproxy"
        "privoxy"
        "haproxy"
        "traefik"
        "varnish"
        "apache2"
        "nginx"
        "lighttpd"
        "caddy"
        "tomcat10"
        "h2o"
        "xinetd"
        "display-manager"
        "postfix"
        "exim4"
        "sendmail"
    )

    > "$BACKUP_DIR/services.status"
    for s in "${SERVICES[@]}"; do
        if systemctl list-unit-files 2>/dev/null | grep -qE "^${s}\.(service|socket)"; then
            enabled=$(systemctl is-enabled "$s" 2>/dev/null || echo "unknown")
            active=$(systemctl is-active "$s" 2>/dev/null || echo "unknown")
            echo "$s $enabled $active" >> "$BACKUP_DIR/services.status"
        fi
    done

    # Package installation state for services packages
    PACKAGES=(
        "cron" "at" "systemd-timesyncd" "chrony" "autofs" "avahi-daemon"
        "isc-dhcp-server" "udhcpd" "kea" "bind9" "unbound" "powerdns"
        "dnsmasq" "vsftpd" "proftpd" "pure-ftpd" "slapd" "ldap-utils"
        "dovecot-imapd" "dovecot-pop3d" "courier-imap" "cyrus-imapd"
        "nfs-kernel-server" "nfs-common" "nis" "yp-tools" "cups"
        "cups-browsed" "rpcbind" "rsync" "samba" "samba-common-bin"
        "snmpd" "snmp" "tftpd-hpa" "atftpd" "squid" "tinyproxy"
        "privoxy" "haproxy" "traefik" "varnish" "apache2" "nginx"
        "lighttpd" "caddy" "tomcat10" "h2o" "xinetd" "xserver-xorg"
        "xorg" "x11-common" "postfix" "exim4" "sendmail"
        "ftp" "tnftp" "rsh-client" "talk" "telnet" "inetutils-telnet"
    )
    dpkg-query -W -f='${Package} ${Status} ${Version}\n' "${PACKAGES[@]}" 2>/dev/null > "$BACKUP_DIR/dpkg.status" || true

    # 3. Kernel Parameters & Modules
    echo "[*] Backing up kernel parameters and modules..."
    sysctl -a > "$BACKUP_DIR/sysctl.status" 2>/dev/null || true
    lsmod > "$BACKUP_DIR/modules.status" 2>/dev/null || true
    if [[ -d "/etc/modprobe.d" ]]; then
        tar -czf "$BACKUP_DIR/modprobe.tar.gz" -C / etc/modprobe.d 2>/dev/null || true
    fi

    # 4. Firewall Rules & Network Settings
    echo "[*] Backing up firewall rules and network settings..."
    if command -v ufw &>/dev/null; then
        ufw status verbose > "$BACKUP_DIR/ufw.status" 2>/dev/null || true
    fi
    if command -v iptables-save &>/dev/null; then
        iptables-save > "$BACKUP_DIR/iptables.rules" 2>/dev/null || true
    fi
    if command -v ip6tables-save &>/dev/null; then
        ip6tables-save > "$BACKUP_DIR/ip6tables.rules" 2>/dev/null || true
    fi
    if command -v nft &>/dev/null; then
        nft list ruleset > "$BACKUP_DIR/nftables.rules" 2>/dev/null || true
    fi

    echo "[+] Initial system state successfully backed up to $BACKUP_DIR"
fi

# -----------------------------------------------------------------------------
# STEP 2: UNSECURE SERVICES SETTINGS (TRIGGER NOT HARDENED AUDIT FAILURES)
# -----------------------------------------------------------------------------
echo "[*] Unsecuring services module settings to trigger NOT HARDENED..."

# 1. Job Schedulers: Cron & At
echo "    [-] Unsecuring cron and at permissions..."
[[ ! -f "/etc/crontab" ]] && touch "/etc/crontab"
chmod 777 "/etc/crontab"

for cdir in "/etc/cron.hourly" "/etc/cron.daily" "/etc/cron.weekly" "/etc/cron.monthly" "/etc/cron.d"; do
    [[ ! -d "$cdir" ]] && mkdir -p "$cdir"
    chmod 777 "$cdir"
done

# Remove /etc/cron.allow and /etc/at.allow to ensure restriction checks fail
if [[ -f "/etc/cron.allow" ]]; then
    chmod 777 "/etc/cron.allow"
fi
rm -f "/etc/cron.allow"

if [[ -f "/etc/at.allow" ]]; then
    chmod 777 "/etc/at.allow"
fi
rm -f "/etc/at.allow"

# Stop and disable cron daemon to trigger cron_daemon audit failure
echo "    [-] Disabling cron service..."
systemctl stop cron.service 2>/dev/null || true
systemctl disable cron.service 2>/dev/null || true

# 2. Time Synchronization
echo "    [-] Unsecuring time synchronization daemons (chrony & timesyncd)..."
# Set up chrony: if chrony.service unit does not exist, provide a test unit so systemctl can enable it
if ! systemctl list-unit-files 2>/dev/null | grep -q "^chrony\.service"; then
    cat << 'EOF' > /etc/systemd/system/chrony.service
[Unit]
Description=Chrony Daemon (Test Unit)
After=network.target

[Service]
Type=simple
ExecStart=/bin/sleep 3600
Restart=no

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload 2>/dev/null || true
    echo "/etc/systemd/system/chrony.service" > "$BACKUP_DIR/test_chrony_unit.txt"
fi

# Enable chrony but keep it stopped (enabled=true, active=false -> fails chrony_enabled)
systemctl enable chrony.service 2>/dev/null || true
systemctl stop chrony.service 2>/dev/null || true

# Invalidate chrony configuration (remove authorized ntp servers)
mkdir -p /etc/chrony /etc/chrony/sources.d
echo "server unsecure.invalid.ntp.local" > /etc/chrony/chrony.conf
rm -f /etc/chrony/sources.d/*.sources 2>/dev/null || true

# Run dummy chronyd process as root (violates run_as_user check _chrony)
pkill -f "exec -a chronyd" 2>/dev/null || true
(exec -a chronyd sleep 3600) &>/dev/null &
echo $! > "$BACKUP_DIR/dummy_chronyd.pid"

# Set timesyncd: enabled but stopped (fails timesyncd_enabled)
# Having BOTH systemd-timesyncd and chrony enabled means active_count=2, failing time_sync_single_daemon!
systemctl enable systemd-timesyncd.service 2>/dev/null || true
systemctl stop systemd-timesyncd.service 2>/dev/null || true

# Invalidate timesyncd configuration (strip NTP servers)
if [[ -d "/etc/systemd/timesyncd.conf.d" ]]; then
    rm -f /etc/systemd/timesyncd.conf.d/*.conf 2>/dev/null || true
fi
if [[ -f "/etc/systemd/timesyncd.conf" ]]; then
    sed -i 's/^\s*NTP=.*/#NTP=/' /etc/systemd/timesyncd.conf 2>/dev/null || true
    sed -i 's/^\s*FallbackNTP=.*/#FallbackNTP=/' /etc/systemd/timesyncd.conf 2>/dev/null || true
fi

# 3. Approved Services: Start unapproved listening service
echo "    [-] Launching dummy unapproved background listener..."
cat << 'EOF' > /etc/systemd/system/beetle_test_listener.service
[Unit]
Description=Beetle Test Unapproved Listener Service
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 -m http.server 9999
Restart=no

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload 2>/dev/null || true
systemctl start beetle_test_listener.service 2>/dev/null || true
echo "beetle_test_listener.service" > "$BACKUP_DIR/test_listener_unit.txt"

# 4. Mail Transfer Agent (MTA)
if command -v postconf &>/dev/null; then
    echo "    [-] Setting Postfix inet_interfaces to all..."
    postconf -e "inet_interfaces = all" 2>/dev/null || true
fi

# 5. Restricted Packages Overlay for Client & Server Services & At
echo "    [-] Injecting restricted service package flags into DPKG_RAM_STORE..."
RESTRICTED_PKGS=()

if [[ -f "$SERVICES_JSON" ]] && command -v python3 &>/dev/null; then
    while IFS= read -r pkg; do
        [[ -n "$pkg" ]] && RESTRICTED_PKGS+=("$pkg")
    done < <(python3 -c "
import json
with open('$SERVICES_JSON') as f:
    d = json.load(f)
pkgs = []
for sec in ['client_services', 'server_services']:
    for cat, pdict in d.get(sec, {}).items():
        for pname, pdata in pdict.items():
            if pdata.get('restrict', True) is True:
                pkgs.append(pname)
print('\n'.join(sorted(set(pkgs))))
")
fi

# Explicitly ensure 'at' is in the unsecure package set so at_restriction check triggers
RESTRICTED_PKGS+=("at")

DPKG_STORE="${DPKG_RAM_STORE:-/dev/shm/beetle_dpkg.env}"
> "$BACKUP_DIR/unsecure_pkgs.env"

for pkg in "${RESTRICTED_PKGS[@]}"; do
    safe_pkg=$(echo "$pkg" | sed 's/[^a-zA-Z0-9_]/_/g')
    echo "PKG_${safe_pkg}=installed" >> "$BACKUP_DIR/unsecure_pkgs.env"
    echo "PKG_${safe_pkg}_version=99.9.9" >> "$BACKUP_DIR/unsecure_pkgs.env"
done

# If DPKG_RAM_STORE exists, append restricted package flags
if [[ -f "$DPKG_STORE" ]]; then
    cat "$BACKUP_DIR/unsecure_pkgs.env" >> "$DPKG_STORE"
fi

echo "[+] Unsecuring complete for $MODULE_NAME. All audit checks primed to fail (NOT HARDENED)."
exit 0
