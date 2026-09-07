#!/usr/bin/env bash
# restore.sh - Restores settings from /tmp/beetle_sysmaint_backup and cleans up test entries.

set -e

BACKUP_DIR="/tmp/beetle_sysmaint_backup"

echo "=== Cleaning up test users/groups created during unsecure ==="
userdel -f unsecure_test_user 2>/dev/null || true
userdel -f unsecure_dup_uid 2>/dev/null || true
userdel -f unsecure_bad_gid 2>/dev/null || true
userdel -f unsecure_noshadow 2>/dev/null || true
groupdel unsecure_dup_grp 2>/dev/null || true
groupdel unsecure_dup_gid1 2>/dev/null || true
groupdel unsecure_dup_gid2 2>/dev/null || true
groupdel group_8888 2>/dev/null || true

# Remove extra lines in /etc/passwd and /etc/group if leftover
sed -i '/^unsecure_/d' /etc/passwd 2>/dev/null || true
sed -i '/^unsecure_/d' /etc/group 2>/dev/null || true

# Restore file backups and permissions
if [ -d "$BACKUP_DIR" ]; then
    echo "=== Restoring backed up system files & permissions ==="
    for meta_file in "$BACKUP_DIR"/*.meta; do
        [ -f "$meta_file" ] || continue
        base_name=$(basename "$meta_file" .meta)
        target_file=$(echo "$base_name" | tr '_' '/')
        
        # Restore backed up file content if file backup exists
        if [ -f "$BACKUP_DIR/$base_name" ]; then
            cp -a "$BACKUP_DIR/$base_name" "$target_file"
        fi
        
        # Restore original mode, owner, group
        if [ -e "$target_file" ]; then
            read -r mode owner group < "$meta_file"
            chmod "$mode" "$target_file" 2>/dev/null || true
            chown "${owner}:${group}" "$target_file" 2>/dev/null || true
        fi
    done
    rm -rf "$BACKUP_DIR"
fi

echo "Restore completed successfully."
