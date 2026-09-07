#!/usr/bin/env bash
# unsecure.sh - Unsecures system_maintenance settings audited and hardened by Beetle.
# Backup store: /tmp/beetle_sysmaint_backup

set -e

BACKUP_DIR="/tmp/beetle_sysmaint_backup"
mkdir -p "$BACKUP_DIR"

echo "=== Backing up current state ==="
# Backup system permission files
FILES=(
    "/etc/passwd"
    "/etc/passwd-"
    "/etc/group"
    "/etc/group-"
    "/etc/shadow"
    "/etc/shadow-"
    "/etc/gshadow"
    "/etc/gshadow-"
    "/etc/shells"
    "/etc/security/opasswd"
    "/etc/security/opasswd.old"
)

for f in "${FILES[@]}"; do
    if [ -f "$f" ]; then
        safe_name=$(echo "$f" | tr '/' '_')
        cp -a "$f" "$BACKUP_DIR/$safe_name"
        stat -c "%a %U %G" "$f" > "$BACKUP_DIR/${safe_name}.meta"
    fi
done

# Backup SUID/SGID state of risky binaries
if [ -f "$PERM_RAM_STORE" ]; then
    source "$PERM_RAM_STORE"
fi
if [ -n "${SS_count:-}" ]; then
    for ((i=0; i<SS_count; i++)); do
        p_var="SS_${i}_path"
        path="${!p_var}"
        if [ -f "$path" ]; then
            safe_bin=$(echo "$path" | tr '/' '_')
            stat -c "%a %U %G" "$path" > "$BACKUP_DIR/${safe_bin}.meta"
        fi
    done
fi

echo "=== Unsecuring system_maintenance settings ==="

# 1. System File Permissions (Set insecure permissions e.g. 777)
for f in "${FILES[@]}"; do
    if [ -f "$f" ]; then
        chmod 777 "$f"
    fi
done

# 2. Local User & Group Settings:
# - shadow_passwd_fields_isempty: Set empty password for a dummy test account if exists or create dummy user with empty password in /etc/shadow
if ! id "unsecure_test_user" &>/dev/null; then
    useradd -m "unsecure_test_user" || true
fi
# Set empty password in /etc/shadow
sed -i 's/^unsecure_test_user:[^:]*:/unsecure_test_user::/' /etc/shadow || true

# - shadow_group_isempty: Add a user to shadow group
usermod -aG shadow unsecure_test_user || true

# - no_duplicate_usernames: Create duplicate username entry in /etc/passwd if possible or duplicate group name in /etc/group
# (Append a duplicate line to /etc/passwd for unsecure_test_user)
if ! grep -q "^unsecure_test_user_dup:" /etc/passwd; then
    echo "unsecure_test_user:x:9999:9999:Duplicate User Test:/home/unsecure_test_user:/bin/bash" >> /etc/passwd
fi

# - no_duplicates_uids: Create duplicate UID in /etc/passwd
if ! grep -q "^unsecure_dup_uid:" /etc/passwd; then
    echo "unsecure_dup_uid:x:9999:9999:Duplicate UID Test:/home/unsecure_test_user:/bin/bash" >> /etc/passwd
fi

# - no_duplicate_grpnames: Create duplicate group name in /etc/group
if ! grep -q "^unsecure_dup_grp:" /etc/group; then
    echo "unsecure_dup_grp:x:9999:" >> /etc/group
    echo "unsecure_dup_grp:x:9998:" >> /etc/group
fi

# - no_duplicate_gids: Create duplicate GID in /etc/group
if ! grep -q "^unsecure_dup_gid1:" /etc/group; then
    echo "unsecure_dup_gid1:x:9997:" >> /etc/group
    echo "unsecure_dup_gid2:x:9997:" >> /etc/group
fi

# - all_groups_exist_in_shadow: Create a user with non-existent GID
if ! grep -q "^unsecure_bad_gid:" /etc/passwd; then
    echo "unsecure_bad_gid:x:9996:8888:Bad GID Test:/home/unsecure_test_user:/bin/bash" >> /etc/passwd
fi

# - all_accounts_use_shadow_passwd: User not using shadowed password (2nd field not 'x')
if ! grep -q "^unsecure_noshadow:" /etc/passwd; then
    echo "unsecure_noshadow:plainpassword:9995:9995:No Shadow Test:/home/unsecure_test_user:/bin/bash" >> /etc/passwd
fi

# 3. suid_sgid_files_review: Add SUID bit to a known risky binary (e.g. /usr/bin/cp or /usr/bin/awk)
if [ -f "/usr/bin/cp" ]; then
    chmod u+s /usr/bin/cp || true
fi

echo "Unsecure completed successfully."
