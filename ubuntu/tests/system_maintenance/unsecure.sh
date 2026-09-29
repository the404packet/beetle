#!/usr/bin/env bash
# unsecure.sh - Unsecures system_maintenance settings audited and hardened by Beetle.
# Backup store: /tmp/beetle_sysmaint_backup

set -e

BACKUP_DIR="/tmp/beetle_sysmaint_backup"
mkdir -p "$BACKUP_DIR"

echo "=== Backing up current state ==="

# ── Backup system permission files ──
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

# ── Backup SUID/SGID state of risky binaries ──
if [ -f "$PERM_RAM_STORE" ]; then
    source "$PERM_RAM_STORE"
fi
if [ -n "${SS_count:-}" ]; then
    for ((i=0; i<SS_count; i++)); do
        p_var="SS_${i}_path"
        path="${!p_var}"
        if [ -f "$path" ]; then
            safe_bin=$(echo "$path" | tr '/' '_')
            cp -a "$path" "$BACKUP_DIR/${safe_bin}" 2>/dev/null || true
            stat -c "%a %U %G" "$path" > "$BACKUP_DIR/${safe_bin}.meta"
        fi
    done
fi

echo "=== Unsecuring system_maintenance settings ==="

# ── Helper: remove any previously created test entries (idempotency) ──
cleanup_unsecure_entries() {
    for f in /etc/passwd /etc/group /etc/shadow /etc/gshadow; do
        [ -f "$f" ] && sed -i '/^unsecure_/d' "$f" 2>/dev/null || true
    done
}
cleanup_unsecure_entries

# ── 1. System File Permissions (Set insecure permissions 777) ──
for f in "${FILES[@]}"; do
    if [ -f "$f" ]; then
        chmod 777 "$f"
    fi
done

# ── 2. Local User & Group Settings ──

# - all_accounts_use_shadow_passwd: create a user with a non-'x' password field
if ! grep -q "^unsecure_noshadow:" /etc/passwd; then
    echo "unsecure_noshadow:plainpassword:9995:9995:No Shadow Test:/home/unsecure_test_user:/bin/bash" >> /etc/passwd
fi

# - Create test user's primary group with a fixed GID that does NOT collide
#   with the duplicate-GID test values (9997) used below.
if ! getent group unsecure_test_user &>/dev/null; then
    groupadd -g 9990 unsecure_test_user 2>/dev/null || true
fi
if ! id "unsecure_test_user" &>/dev/null; then
    useradd -m -u 9990 -g 9990 "unsecure_test_user" 2>/dev/null || true
fi

# - shadow_passwd_fields_isempty: set an empty password in /etc/shadow
sed -i 's/^unsecure_test_user:[^:]*:/unsecure_test_user::/' /etc/shadow 2>/dev/null || true

# - shadow_group_isempty: add a user to the shadow group
usermod -aG shadow unsecure_test_user 2>/dev/null || true

# - no_duplicate_usernames: two distinct /etc/passwd lines with the same name
if ! grep -q "^unsecure_test_user_dup:" /etc/passwd; then
    echo "unsecure_test_user:x:9999:9990:Duplicate User Test:/home/unsecure_test_user:/bin/bash" >> /etc/passwd
fi

# - no_duplicates_uids: two lines with the same UID 9999
if ! grep -q "^unsecure_dup_uid:" /etc/passwd; then
    echo "unsecure_dup_uid:x:9999:9990:Duplicate UID Test:/home/unsecure_test_user:/bin/bash" >> /etc/passwd
fi

# - no_duplicate_grpnames: two lines with the same group name
if ! grep -q "^unsecure_dup_grp:" /etc/group; then
    echo "unsecure_dup_grp:x:9998:" >> /etc/group
    echo "unsecure_dup_grp:x:9999:" >> /etc/group
fi

# - no_duplicate_gids: two lines with the same GID 9997
if ! grep -q "^unsecure_dup_gid1:" /etc/group; then
    echo "unsecure_dup_gid1:x:9997:" >> /etc/group
    echo "unsecure_dup_gid2:x:9997:" >> /etc/group
fi

# - all_groups_exist_in_shadow: user with a GID that doesn't exist in /etc/group
if ! grep -q "^unsecure_bad_gid:" /etc/passwd; then
    echo "unsecure_bad_gid:x:9996:8888:Bad GID Test:/home/unsecure_test_user:/bin/bash" >> /etc/passwd
fi

# ── 3. suid_sgid_files_review: add SUID bit to a known risky binary ──
if [ -f "/usr/bin/cp" ]; then
    chmod u+s /usr/bin/cp 2>/dev/null || true
fi

echo "Unsecure completed successfully."