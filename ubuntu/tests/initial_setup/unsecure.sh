#!/usr/bin/env bash
# unsecure.sh - Unsecures initial_setup settings audited and hardened by Beetle.
# Backup store: /tmp/beetle_initial_setup_backup

set -e

BACKUP_DIR="/tmp/beetle_initial_setup_backup"
mkdir -p "$BACKUP_DIR"

echo "=== Backing up current initial_setup state ==="

# ── 1. System File Permissions & Content Backup ──
FILES=(
    "/etc/sysctl.conf"
    "/etc/sysctl.d/60-kernel_sysctl.conf"
    "/etc/default/apport"
    "/etc/security/limits.conf"
    "/etc/systemd/coredump.conf"
    "/boot/grub/grub.cfg"
    "/etc/default/grub"
    "/etc/grub.d/40_custom"
    "/etc/issue"
    "/etc/issue.net"
    "/etc/motd"
    "/etc/gdm3/custom.conf"
    "/etc/dconf/profile/gdm"
    "/etc/apt/sources.list"
)

for f in "${FILES[@]}"; do
    if [ -f "$f" ]; then
        safe_name=$(echo "$f" | tr '/' '_')
        cp -a "$f" "$BACKUP_DIR/$safe_name"
        stat -c "%a %U %G" "$f" > "$BACKUP_DIR/${safe_name}.meta"
    fi
done

# Backup directories
if [ -d "/etc/dconf/db/gdm.d" ]; then
    cp -a "/etc/dconf/db/gdm.d" "$BACKUP_DIR/dconf_gdm.d_dir"
fi
if [ -d "/etc/modprobe.d" ]; then
    cp -a "/etc/modprobe.d" "$BACKUP_DIR/modprobe.d_dir"
fi
if [ -d "/etc/apt/sources.list.d" ]; then
    cp -a "/etc/apt/sources.list.d" "$BACKUP_DIR/sources.list.d_dir"
fi

# ── 2. Kernel Parameters Backup ──
sysctl kernel.randomize_va_space 2>/dev/null | awk -F= '{print $2}' | xargs > "$BACKUP_DIR/sysctl_randomize_va_space.val" || echo "2" > "$BACKUP_DIR/sysctl_randomize_va_space.val"
sysctl fs.suid_dumpable 2>/dev/null | awk -F= '{print $2}' | xargs > "$BACKUP_DIR/sysctl_suid_dumpable.val" || echo "0" > "$BACKUP_DIR/sysctl_suid_dumpable.val"
sysctl kernel.yama.ptrace_scope 2>/dev/null | awk -F= '{print $2}' | xargs > "$BACKUP_DIR/sysctl_ptrace_scope.val" || echo "1" > "$BACKUP_DIR/sysctl_ptrace_scope.val"

# Backup loaded modules
lsmod > "$BACKUP_DIR/lsmod.out" 2>/dev/null || true

# ── 3. Systemd Services Backup ──
SERVICES=("apport.service" "gdm3.service" "gdm.service" "apparmor.service")
for svc in "${SERVICES[@]}"; do
    safe_svc=$(echo "$svc" | tr '.' '_')
    systemctl is-enabled "$svc" 2>/dev/null > "$BACKUP_DIR/${safe_svc}.enabled" || echo "disabled" > "$BACKUP_DIR/${safe_svc}.enabled"
    systemctl is-active "$svc" 2>/dev/null > "$BACKUP_DIR/${safe_svc}.active" || echo "inactive" > "$BACKUP_DIR/${safe_svc}.active"
done

# ── 4. Package Installation State Backup ──
PACKAGES=("prelink" "gdm3" "apparmor" "apparmor-utils")
for pkg in "${PACKAGES[@]}"; do
    dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null > "$BACKUP_DIR/pkg_${pkg}.status" || echo "not-installed" > "$BACKUP_DIR/pkg_${pkg}.status"
done

# ── 5. Firewall Rules & Network Settings Backup ──
ufw status verbose > "$BACKUP_DIR/ufw.status" 2>/dev/null || echo "inactive" > "$BACKUP_DIR/ufw.status"
iptables-save > "$BACKUP_DIR/iptables.rules" 2>/dev/null || true

echo "=== Unsecuring initial_setup settings ==="

# ── 1. Additional Process Hardening ──
# ASLR -> set to 0 (disabled)
sysctl -w kernel.randomize_va_space=0 2>/dev/null || true

# Apport (Automatic Error Reporting) -> enable
if [ -f "/etc/default/apport" ]; then
    sed -i 's/^enabled=.*/enabled=1/' /etc/default/apport 2>/dev/null || echo "enabled=1" >> /etc/default/apport
fi
systemctl start apport 2>/dev/null || true

# Core dumps restricted -> fs.suid_dumpable=1, limits.conf, coredump.conf
sysctl -w fs.suid_dumpable=1 2>/dev/null || true
if [ -f "/etc/security/limits.conf" ]; then
    sed -i '/\* hard core 0/d' /etc/security/limits.conf 2>/dev/null || true
    echo "* soft core unlimited" >> /etc/security/limits.conf
fi
if [ -f "/etc/systemd/coredump.conf" ]; then
    sed -i 's/^Storage=.*/Storage=external/' /etc/systemd/coredump.conf 2>/dev/null || echo "Storage=external" >> /etc/systemd/coredump.conf
    sed -i 's/^ProcessSizeMax=.*/ProcessSizeMax=2G/' /etc/systemd/coredump.conf 2>/dev/null || echo "ProcessSizeMax=2G" >> /etc/systemd/coredump.conf
fi

# Ptrace scope -> 0
sysctl -w kernel.yama.ptrace_scope=0 2>/dev/null || true

# ── 2. Bootloader Configuration ──
if [ -f "/boot/grub/grub.cfg" ]; then
    chmod 777 /boot/grub/grub.cfg 2>/dev/null || true
fi
if [ -f "/etc/default/grub" ]; then
    chmod 777 /etc/default/grub 2>/dev/null || true
    # Unsecure AppArmor bootloader setting
    sed -i 's/apparmor=1//g' /etc/default/grub 2>/dev/null || true
    sed -i 's/security=apparmor//g' /etc/default/grub 2>/dev/null || true
fi
if [ -f "/etc/grub.d/40_custom" ]; then
    chmod 777 /etc/grub.d/40_custom 2>/dev/null || true
    sed -i '/password_pbkdf2/d' /etc/grub.d/40_custom 2>/dev/null || true
    sed -i '/set superusers/d' /etc/grub.d/40_custom 2>/dev/null || true
fi

# ── 3. Command Line Warning Banners ──
for bfile in /etc/issue /etc/issue.net /etc/motd; do
    if [ -f "$bfile" ]; then
        chmod 777 "$bfile" 2>/dev/null || true
        # Put OS info escape sequence so banner checks fail
        echo 'Welcome to \s \r \m \v' > "$bfile"
    fi
done

# ── 4. GNOME Display Manager (GDM) Settings ──
if [ -f "/etc/gdm3/custom.conf" ]; then
    chmod 777 /etc/gdm3/custom.conf 2>/dev/null || true
    if grep -q '\[xdmcp\]' /etc/gdm3/custom.conf; then
        sed -i '/\[xdmcp\]/a Enable=true' /etc/gdm3/custom.conf 2>/dev/null || true
    else
        echo -e "\n[xdmcp]\nEnable=true" >> /etc/gdm3/custom.conf
    fi
fi

if [ -d "/etc/dconf/db/gdm.d" ]; then
    rm -rf /etc/dconf/db/gdm.d/* 2>/dev/null || true
fi

# ── 5. Filesystem Kernel Modules ──
# Remove modprobe configs blocking filesystem modules
FS_MODULES=("cramfs" "freevxfs" "hfs" "hfsplus" "jffs2" "overlayfs" "squashfs" "udf" "usb-storage")
for mod in "${FS_MODULES[@]}"; do
    rm -f "/etc/modprobe.d/${mod}.conf" 2>/dev/null || true
    # Clean any install / blacklist entries in /etc/modprobe.d/
    if [ -d "/etc/modprobe.d" ]; then
        sed -i "/install ${mod} /d" /etc/modprobe.d/*.conf 2>/dev/null || true
        sed -i "/blacklist ${mod}/d" /etc/modprobe.d/*.conf 2>/dev/null || true
    fi
done

echo "Unsecure completed successfully for initial_setup module."
