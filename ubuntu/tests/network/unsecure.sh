#!/usr/bin/env bash
# unsecure.sh - Unsecures all network module settings checked by Beetle audit/harden scripts.
# Backup store: /tmp/beetle_network_backup

set -e

BACKUP_DIR="/tmp/beetle_network_backup"
mkdir -p "$BACKUP_DIR"

echo "=== Backing up current network state ==="

# --- 1. Kernel sysctl parameters ---
# Capture all network-related sysctl values we will modify
SYSCTL_PARAMS=(
    "net.ipv4.ip_forward"
    "net.ipv6.conf.all.forwarding"
    "net.ipv4.conf.all.send_redirects"
    "net.ipv4.conf.default.send_redirects"
    "net.ipv4.icmp_ignore_bogus_error_responses"
    "net.ipv4.icmp_echo_ignore_broadcasts"
    "net.ipv4.conf.all.accept_redirects"
    "net.ipv4.conf.default.accept_redirects"
    "net.ipv4.conf.all.secure_redirects"
    "net.ipv4.conf.default.secure_redirects"
    "net.ipv4.conf.all.rp_filter"
    "net.ipv4.conf.default.rp_filter"
    "net.ipv4.conf.all.accept_source_route"
    "net.ipv4.conf.default.accept_source_route"
    "net.ipv4.conf.all.log_martians"
    "net.ipv4.conf.default.log_martians"
    "net.ipv4.tcp_syncookies"
    "net.ipv6.conf.all.accept_redirects"
    "net.ipv6.conf.default.accept_redirects"
    "net.ipv6.conf.all.accept_source_route"
    "net.ipv6.conf.default.accept_source_route"
    "net.ipv6.conf.all.accept_ra"
    "net.ipv6.conf.default.accept_ra"
)

for param in "${SYSCTL_PARAMS[@]}"; do
    val=$(sysctl -n "$param" 2>/dev/null || echo "")
    echo "${param}=${val}" >> "$BACKUP_DIR/sysctl_backup.conf"
done

# --- 2. Sysctl config files ---
for f in /etc/sysctl.d/60-netipv4_sysctl.conf /etc/sysctl.d/60-netipv6_sysctl.conf; do
    if [ -f "$f" ]; then
        safe=$(echo "$f" | tr '/' '_')
        cp -a "$f" "$BACKUP_DIR/${safe}"
        stat -c "%a %U %G" "$f" > "$BACKUP_DIR/${safe}.meta"
    fi
done

# --- 3. Kernel modules (modprobe configs) ---
for mod in dccp tipc rds sctp; do
    conf="/etc/modprobe.d/${mod}.conf"
    if [ -f "$conf" ]; then
        cp -a "$conf" "$BACKUP_DIR/modprobe_${mod}.conf"
    fi
    # Save whether module is currently loaded
    lsmod | grep -qw "$mod" && echo "loaded" > "$BACKUP_DIR/lsmod_${mod}" || echo "not_loaded" > "$BACKUP_DIR/lsmod_${mod}"
done

# --- 4. Bluetooth service state & package ---
dpkg-query -W -f='${Status}' bluez 2>/dev/null > "$BACKUP_DIR/pkg_bluez.status" || echo "not-installed" > "$BACKUP_DIR/pkg_bluez.status"
systemctl is-enabled bluetooth.service 2>/dev/null > "$BACKUP_DIR/bluetooth.enabled" || echo "disabled" > "$BACKUP_DIR/bluetooth.enabled"
systemctl is-active bluetooth.service 2>/dev/null > "$BACKUP_DIR/bluetooth.active" || echo "inactive" > "$BACKUP_DIR/bluetooth.active"

# --- 5. Wireless interfaces state ---
if command -v nmcli &>/dev/null; then
    nmcli radio wifi 2>/dev/null > "$BACKUP_DIR/wifi_radio" || echo "unknown" > "$BACKUP_DIR/wifi_radio"
fi

echo "=== Unsecuring network settings ==="

# --- 0. Ensure bluez package is installed and service is unmasked/enabled/started ---
if ! dpkg -l bluez &>/dev/null; then
    apt-get install -y -q bluez 2>/dev/null || true
fi
systemctl unmask bluetooth.service 2>/dev/null || true
systemctl enable bluetooth.service 2>/dev/null || true
systemctl start bluetooth.service 2>/dev/null || true

# --- 1. Set insecure sysctl values (opposite of what audit expects) ---
sysctl -w net.ipv4.ip_forward=1                           2>/dev/null || true
sysctl -w net.ipv6.conf.all.forwarding=1                  2>/dev/null || true
sysctl -w net.ipv4.conf.all.send_redirects=1              2>/dev/null || true
sysctl -w net.ipv4.conf.default.send_redirects=1          2>/dev/null || true
sysctl -w net.ipv4.icmp_ignore_bogus_error_responses=0    2>/dev/null || true
sysctl -w net.ipv4.icmp_echo_ignore_broadcasts=0          2>/dev/null || true
sysctl -w net.ipv4.conf.all.accept_redirects=1            2>/dev/null || true
sysctl -w net.ipv4.conf.default.accept_redirects=1        2>/dev/null || true
sysctl -w net.ipv4.conf.all.secure_redirects=1            2>/dev/null || true
sysctl -w net.ipv4.conf.default.secure_redirects=1        2>/dev/null || true
sysctl -w net.ipv4.conf.all.rp_filter=0                   2>/dev/null || true
sysctl -w net.ipv4.conf.default.rp_filter=0               2>/dev/null || true
sysctl -w net.ipv4.conf.all.accept_source_route=1         2>/dev/null || true
sysctl -w net.ipv4.conf.default.accept_source_route=1     2>/dev/null || true
sysctl -w net.ipv4.conf.all.log_martians=0                2>/dev/null || true
sysctl -w net.ipv4.conf.default.log_martians=0            2>/dev/null || true
sysctl -w net.ipv4.tcp_syncookies=0                       2>/dev/null || true
sysctl -w net.ipv6.conf.all.accept_redirects=1            2>/dev/null || true
sysctl -w net.ipv6.conf.default.accept_redirects=1        2>/dev/null || true
sysctl -w net.ipv6.conf.all.accept_source_route=1         2>/dev/null || true
sysctl -w net.ipv6.conf.default.accept_source_route=1     2>/dev/null || true
sysctl -w net.ipv6.conf.all.accept_ra=1                   2>/dev/null || true
sysctl -w net.ipv6.conf.default.accept_ra=1               2>/dev/null || true

# Disable IPv6 via sysctl so IPv6 status audit fails (reports NOT HARDENED when config expects enabled)
sysctl -w net.ipv6.conf.all.disable_ipv6=1                2>/dev/null || true
sysctl -w net.ipv6.conf.default.disable_ipv6=1            2>/dev/null || true

# Write insecure values into sysctl config files so file audit checks fail initially,
# and harden scripts can locate and update the file properly
mkdir -p /etc/sysctl.d
cat << 'EOF' > /etc/sysctl.d/60-netipv4_sysctl.conf
net.ipv4.ip_forward = 1
net.ipv4.conf.all.send_redirects = 1
net.ipv4.conf.default.send_redirects = 1
net.ipv4.icmp_ignore_bogus_error_responses = 0
net.ipv4.icmp_echo_ignore_broadcasts = 0
net.ipv4.conf.all.accept_redirects = 1
net.ipv4.conf.default.accept_redirects = 1
net.ipv4.conf.all.secure_redirects = 1
net.ipv4.conf.default.secure_redirects = 1
net.ipv4.conf.all.rp_filter = 0
net.ipv4.conf.default.rp_filter = 0
net.ipv4.conf.all.accept_source_route = 1
net.ipv4.conf.default.accept_source_route = 1
net.ipv4.conf.all.log_martians = 0
net.ipv4.conf.default.log_martians = 0
net.ipv4.tcp_syncookies = 0
EOF

cat << 'EOF' > /etc/sysctl.d/60-netipv6_sysctl.conf
net.ipv6.conf.all.forwarding = 1
net.ipv6.conf.all.accept_redirects = 1
net.ipv6.conf.default.accept_redirects = 1
net.ipv6.conf.all.accept_source_route = 1
net.ipv6.conf.default.accept_source_route = 1
net.ipv6.conf.all.accept_ra = 1
net.ipv6.conf.default.accept_ra = 1
EOF

# --- 2. Unsecure kernel modules (install extra modules package, load modules, remove blocklists) ---
# Try installing linux-modules-extra for current kernel if available
apt-get install -y -q "linux-modules-extra-$(uname -r)" 2>/dev/null || true

for mod in dccp tipc rds sctp; do
    rm -f "/etc/modprobe.d/${mod}.conf"
    modprobe "$mod" 2>/dev/null || true
done

# --- 3. Enable wifi if blocked (audit expects it restricted) ---
if command -v nmcli &>/dev/null; then
    nmcli radio wifi on 2>/dev/null || true
fi

echo "Unsecure completed successfully for network module."
