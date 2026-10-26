#!/usr/bin/env bash
# unsecure.sh - Unsecures access_control settings audited and hardened by Beetle.
# Backup store: /tmp/beetle_access_control_backup

set -e

BACKUP_DIR="/tmp/beetle_access_control_backup"
mkdir -p "$BACKUP_DIR"

echo "=== Backing up current state ==="

# 1. Backup system files & permissions
FILES=(
    "/etc/ssh/sshd_config"
    "/etc/sudoers"
    "/etc/pam.d/common-auth"
    "/etc/pam.d/common-account"
    "/etc/pam.d/common-password"
    "/etc/pam.d/common-session"
    "/etc/pam.d/common-session-noninteractive"
    "/etc/pam.d/su"
    "/etc/security/faillock.conf"
    "/etc/security/pwquality.conf"
    "/etc/security/limits.conf"
    "/etc/login.defs"
    "/etc/default/useradd"
    "/etc/passwd"
    "/etc/passwd-"
    "/etc/group"
    "/etc/group-"
    "/etc/shadow"
    "/etc/shadow-"
    "/etc/gshadow"
    "/etc/gshadow-"
    "/etc/shells"
    "/etc/profile"
    "/etc/profile.d/50-systemwide_tmout.sh"
    "/etc/profile.d/50-systemwide_umask.sh"
    "/etc/bash.bashrc"
    "/root/.bashrc"
    "/root/.bash_profile"
    "/etc/environment"
    "/etc/issue"
    "/etc/issue.net"
    "/etc/motd"
    "/var/log/sudo.log"
)

# Expand SSH host keys into FILES
for hk in /etc/ssh/ssh_host_*; do
    if [ -f "$hk" ]; then
        FILES+=("$hk")
    fi
done

for f in "${FILES[@]}"; do
    if [ -f "$f" ]; then
        safe_name=$(echo "$f" | tr '/' '_')
        cp -a "$f" "$BACKUP_DIR/$safe_name"
        stat -c "%a %U %G" "$f" > "$BACKUP_DIR/${safe_name}.meta"
        echo "$f" > "$BACKUP_DIR/${safe_name}.path"
    fi
done

# Backup directories (/etc/ssh/sshd_config.d, /etc/sudoers.d, /etc/security/limits.d, /etc/pam.d, /usr/share/pam-configs)
DIRS=(
    "/etc/ssh/sshd_config.d"
    "/etc/sudoers.d"
    "/etc/security/limits.d"
    "/etc/pam.d"
    "/usr/share/pam-configs"
)

for d in "${DIRS[@]}"; do
    if [ -d "$d" ]; then
        safe_d=$(echo "$d" | tr '/' '_')
        cp -rP "$d" "$BACKUP_DIR/${safe_d}_dir"
        stat -c "%a %U %G" "$d" > "$BACKUP_DIR/${safe_d}_dir.meta"
        echo "$d" > "$BACKUP_DIR/${safe_d}_dir.path"
    fi
done

# 2. Backup Systemd Services (ssh, sshd) & Package versions
SERVICES=("ssh" "sshd")
for s in "${SERVICES[@]}"; do
    if systemctl list-unit-files | grep -q "^${s}\.service"; then
        enabled=$(systemctl is-enabled "$s" 2>/dev/null || echo "unknown")
        active=$(systemctl is-active "$s" 2>/dev/null || echo "unknown")
        echo "$s $enabled $active" >> "$BACKUP_DIR/services.status"
    fi
done

PKGS=("openssh-server" "sudo" "libpam-modules" "libpam-runtime" "libpam-pwquality")
for p in "${PKGS[@]}"; do
    dpkg-query -W -f='${Package} ${Status} ${Version}\n' "$p" >> "$BACKUP_DIR/dpkg.status" 2>/dev/null || true
done

# 3. Backup Kernel Parameters & Modules
sysctl -a > "$BACKUP_DIR/sysctl.status" 2>/dev/null || true
lsmod > "$BACKUP_DIR/modules.status" 2>/dev/null || true
if [ -d "/etc/modprobe.d" ]; then
    cp -rP "/etc/modprobe.d" "$BACKUP_DIR/modprobe.d"
fi

# 4. Backup Firewall Rules & Network Settings
if command -v ufw &>/dev/null; then
    ufw status verbose > "$BACKUP_DIR/ufw.status" 2>/dev/null || true
fi
if command -v iptables-save &>/dev/null; then
    iptables-save > "$BACKUP_DIR/iptables.rules" 2>/dev/null || true
fi

echo "=== Unsecuring access_control settings ==="

# --- Unsecure SSH Server Config ---
if [ -d "/etc/ssh" ]; then
    mkdir -p /etc/ssh
    if [ ! -f "/etc/ssh/sshd_config" ]; then
        touch /etc/ssh/sshd_config
    fi
    chmod 0644 /etc/ssh/sshd_config

    # Clear all sshd_config.d override files — sshd -T reads these and they
    # override the base config, keeping hardened values even after we rewrite sshd_config.
    if [ -d "/etc/ssh/sshd_config.d" ]; then
        find /etc/ssh/sshd_config.d -maxdepth 1 -type f -name '*.conf' -delete 2>/dev/null || true
    fi

    # Write insecure OpenSSH config (no Include so nothing overrides it)
    cat << 'EOF' > /etc/ssh/sshd_config
# Beetle Unsecure Test Config
LogLevel DEBUG
LoginGraceTime 120
MaxAuthTries 10
MaxSessions 20
MaxStartups 100:30:100
ClientAliveInterval 0
ClientAliveCountMax 0
PermitRootLogin yes
PermitEmptyPasswords yes
PermitUserEnvironment yes
GSSAPIAuthentication yes
HostbasedAuthentication yes
IgnoreRhosts no
DisableForwarding no
UsePAM yes
Ciphers 3des-cbc,blowfish-cbc,aes128-cbc
MACs hmac-md5,hmac-sha1-96
KexAlgorithms diffie-hellman-group1-sha1
EOF

    # Ensure dummy host keys exist with insecure permissions
    for keytype in rsa ecdsa ed25519; do
        priv_key="/etc/ssh/ssh_host_${keytype}_key"
        pub_key="/etc/ssh/ssh_host_${keytype}_key.pub"
        if [ ! -f "$priv_key" ]; then
            ssh-keygen -q -N "" -t "$keytype" -f "$priv_key" 2>/dev/null || touch "$priv_key"
        fi
        if [ ! -f "$pub_key" ]; then
            touch "$pub_key"
        fi
        chmod 0644 "$priv_key"
        chmod 0666 "$pub_key"
    done
else
    # SSH not installed - nothing to unsecure for SSH
    echo "  [INFO] /etc/ssh not found, skipping SSH unsecure (treated as HARDENED by audit)"
fi

# --- Unsecure Sudo Config ---
if [ -f "/etc/sudoers" ]; then
    chmod 0640 /etc/sudoers
    sed -i '/use_pty/d' /etc/sudoers || true
    sed -i '/logfile/d' /etc/sudoers || true
    sed -i '/timestamp_timeout/d' /etc/sudoers || true
    sed -i '/!authenticate/d' /etc/sudoers || true
    sed -i '/NOPASSWD/d' /etc/sudoers || true
    echo "Defaults timestamp_timeout=30" >> /etc/sudoers
    echo "Defaults !authenticate" >> /etc/sudoers
    echo "ALL ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
fi
rm -f /var/log/sudo.log

if [ -f "/etc/pam.d/su" ]; then
    sed -i 's/.*pam_wheel.so.*/# &/' /etc/pam.d/su || true
fi

# --- Unsecure PAM Config ---
mkdir -p /etc/security

# Weaken faillock settings (high deny, long unlock time)
cat << 'EOF' > /etc/security/faillock.conf
deny = 10
unlock_time = 100
EOF

# Clear pwquality.conf.d override directory — audit scripts check both
# /etc/security/pwquality.conf AND /etc/security/pwquality.conf.d/*.conf,
# so any leftover hardened overrides in .conf.d keep reporting HARDENED.
mkdir -p /etc/security/pwquality.conf.d
find /etc/security/pwquality.conf.d -maxdepth 1 -type f -name '*.conf' -delete 2>/dev/null || true

# Write a weak pwquality.conf.
# Strategy per audit logic:
#   - maxrepeat:    audit checks for value in [1-3]  → set to 0 (absent/out of range = NOT HARDENED)
#   - maxsequence:  audit checks for value in [1-3]  → set to 0 (absent/out of range = NOT HARDENED)
#   - minlen:       audit checks for value >=14       → set to 4 (below threshold = NOT HARDENED)
#   - difok:        audit checks for value >=2        → set to 0 (below threshold = NOT HARDENED)
#   - minclass/[dulo]credit: audit checks any are SET and not >0 → remove entirely = NOT HARDENED
#   - enforce_for_root: audit checks if line EXISTS (any value) → remove entirely = NOT HARDENED
#   - enforcing:    audit is HARDENED when enforcing=0 is ABSENT → set to 0 = NOT HARDENED
cat << 'EOF' > /etc/security/pwquality.conf
# Beetle Unsecure Test Config
minlen = 4
maxrepeat = 0
maxsequence = 0
difok = 0
dictcheck = 0
enforcing = 0
EOF

# Remove pam_faillock from common-auth (so pam_faillock audit = NOT HARDENED)
# but keep pam_unix intact so the auth chain still works
if [ -f "/etc/pam.d/common-auth" ]; then
    sed -i '/pam_faillock\.so/d' /etc/pam.d/common-auth || true
fi

# Remove pam_faillock from common-account
if [ -f "/etc/pam.d/common-account" ]; then
    sed -i '/pam_faillock\.so/d' /etc/pam.d/common-account || true
fi

# Also remove faillock/faillock_notify pam-configs so pam-auth-update doesn't re-add them
rm -f /usr/share/pam-configs/faillock 2>/dev/null || true
rm -f /usr/share/pam-configs/faillock_notify 2>/dev/null || true

# Weaken common-password: change hash algo to md5, remove use_authtok from pam_unix,
# add nullok, remove pam_pwhistory enforce_for_root, disable pam_pwquality
if [ -f "/etc/pam.d/common-password" ]; then
    # Change hash algo from yescrypt/sha512 to md5
    sed -i -E 's/\b(yescrypt|sha512)\b/md5/g' /etc/pam.d/common-password || true
    # Remove use_authtok from pam_unix line in password section
    sed -i '/pam_unix\.so/s/ use_authtok//g' /etc/pam.d/common-password || true
    # Add nullok to pam_unix if not present
    if ! grep -q "nullok" /etc/pam.d/common-password; then
        sed -i 's/pam_unix\.so/pam_unix.so nullok/' /etc/pam.d/common-password || true
    fi
    # Disable pam_pwquality in common-password
    sed -i 's/^\(.*pam_pwquality\.so.*\)$/# \1/' /etc/pam.d/common-password || true
    # Disable pam_pwhistory in common-password (removes enforce_for_root check)
    sed -i 's/^\(.*pam_pwhistory\.so.*\)$/# \1/' /etc/pam.d/common-password || true
fi

# Also update /usr/share/pam-configs/unix so pam-auth-update regeneration is consistent
if [ -f "/usr/share/pam-configs/unix" ]; then
    sed -i -E 's/\b(yescrypt|sha512)\b/md5/g' /usr/share/pam-configs/unix || true
    sed -i 's/ use_authtok//g' /usr/share/pam-configs/unix || true
fi

# Remove pam_pwhistory pam-config entirely so pam-auth-update won't re-add it.
# The harden script (pam_pwhistory_enabled.sh) recreates it when hardening.
rm -f /usr/share/pam-configs/pwhistory 2>/dev/null || true

# Remove pam_pwquality pam-config entirely so pam-auth-update won't re-add it.
# This ensures common-password has no active pam_pwquality.so line (NOT HARDENED).
# The harden script (pam_pwquality_enabled.sh) recreates it when hardening.
rm -f /usr/share/pam-configs/pwquality 2>/dev/null || true

# --- Unsecure User Accounts & Environment ---
if [ -f "/etc/login.defs" ]; then
    sed -i 's/^PASS_MAX_DAYS.*/PASS_MAX_DAYS 99999/' /etc/login.defs || true
    sed -i 's/^PASS_MIN_DAYS.*/PASS_MIN_DAYS 0/' /etc/login.defs || true
    sed -i 's/^PASS_WARN_AGE.*/PASS_WARN_AGE 1/' /etc/login.defs || true
    sed -i 's/^ENCRYPT_METHOD.*/ENCRYPT_METHOD MD5/' /etc/login.defs || true
    sed -i 's/^UMASK.*/UMASK 000/' /etc/login.defs || true
fi

if [ -f "/etc/default/useradd" ]; then
    sed -i 's/^INACTIVE=.*/INACTIVE=-1/' /etc/default/useradd || true
    sed -i 's/^SHELL=.*/SHELL=\/bin\/bash/' /etc/default/useradd || true
fi

# Remove umask / tmout profile scripts
rm -f /etc/profile.d/50-systemwide_tmout.sh
rm -f /etc/profile.d/50-systemwide_umask.sh

# Unsecure /etc/shells (add nologin if missing so it's listed)
if [ -f "/etc/shells" ]; then
    for nologin_path in /usr/sbin/nologin /sbin/nologin; do
        if [ -f "$nologin_path" ] && ! grep -q "$nologin_path" /etc/shells; then
            echo "$nologin_path" >> /etc/shells
        fi
    done
fi

# Unsecure root umask & root path
if [ -f "/root/.bashrc" ]; then
    # Remove any existing beetle-injected umask/PATH lines to avoid duplicates
    sed -i '/^umask 0[0-7][0-7]/d' /root/.bashrc || true
    sed -i '/export PATH.*\./d' /root/.bashrc || true
    echo "umask 000" >> /root/.bashrc
    echo 'export PATH="$PATH:."' >> /root/.bashrc
fi
if [ -f "/root/.bash_profile" ]; then
    sed -i '/^umask 0[0-7][0-7]/d' /root/.bash_profile || true
    echo "umask 000" >> /root/.bash_profile
fi

# Unsecure accounts in /etc/passwd & /etc/shadow
# Use a UID range well above 1000 to avoid real system users
if ! grep -q "^unsecure_uid0:" /etc/passwd; then
    echo "unsecure_uid0:x:0:0:Fake Root Account:/home/unsecure_uid0:/bin/bash" >> /etc/passwd
fi

if ! grep -q "^unsecure_gid0:" /etc/passwd; then
    echo "unsecure_gid0:x:9998:0:Fake GID0 Account:/home/unsecure_gid0:/bin/bash" >> /etc/passwd
fi

if ! grep -q "^unsecure_sys:" /etc/passwd; then
    echo "unsecure_sys:x:555:555:System Test Account:/home/unsecure_sys:/bin/bash" >> /etc/passwd
fi

if ! grep -q "^unsecure_nologin_unlocked:" /etc/passwd; then
    echo "unsecure_nologin_unlocked:x:9997:9997:Nologin Unlocked Account:/home/unsecure_nologin_unlocked:/bin/false" >> /etc/passwd
    echo "unsecure_nologin_unlocked:\$6\$saltsalt\$hashhash:19000:0:99999:7:::" >> /etc/shadow
fi

if ! grep -q "^unsecure_grp0:" /etc/group; then
    echo "unsecure_grp0:x:0:" >> /etc/group
fi

# Set root password to empty in /etc/shadow for root access control audit
sed -i 's/^root:[^:]*:/root::/' /etc/shadow || true

# Set last password change date to future for unsecure_nologin_unlocked
if grep -q "^unsecure_nologin_unlocked:" /etc/shadow; then
    sed -i 's/^unsecure_nologin_unlocked:[^:]*:[0-9]*/unsecure_nologin_unlocked:\$6\$saltsalt\$hashhash:99999/' /etc/shadow || true
fi

echo "Unsecure access_control completed successfully."
