#!/usr/bin/env bash
# restore.sh - Restores settings from /tmp/beetle_sysmaint_backup and cleans up test entries.

set -e

BACKUP_DIR="/tmp/beetle_sysmaint_backup"

echo "=== Cleaning up test users/groups created during unsecure ==="

# ── Delete test users first (with homes) ──
for u in unsecure_test_user unsecure_dup_uid unsecure_bad_gid unsecure_noshadow; do
    userdel -rf "$u" 2>/dev/null || true
done

# ── Delete test groups by name ──
for g in unsecure_test_user unsecure_dup_grp unsecure_dup_gid1 unsecure_dup_gid2; do
    groupdel "$g" 2>/dev/null || true
done

# ── Delete any leftover groups matching test patterns ──
# (a) unsecure_*  (b) group_NNNN created by harden scripts
awk -F: '$1 ~ /^unsecure_/ || $1 ~ /^group_[0-9]+$/ {print $1}' /etc/group 2>/dev/null | \
    while IFS= read -r g; do
        groupdel "$g" 2>/dev/null || true
    done

# ── Remove any raw leftover lines from the database files ──
for f in /etc/passwd /etc/group /etc/shadow /etc/gshadow; do
    [ -f "$f" ] && sed -i '/^unsecure_/d' "$f" 2>/dev/null || true
done

# group_NNNN entries only live in /etc/group and /etc/gshadow
sed -i -E '/^group_[0-9]+:/d' /etc/group 2>/dev/null || true
sed -i -E '/^group_[0-9]+:/d' /etc/gshadow 2>/dev/null || true

# ── Remove test user home if it survived ──
rm -rf /home/unsecure_test_user 2>/dev/null || true

# ── Restore file backups and permissions ──
if [ -d "$BACKUP_DIR" ]; then
    echo "=== Restoring backed up system files & permissions ==="

    # Restore file contents first
    for backup_file in "$BACKUP_DIR"/*; do
        [ -f "$backup_file" ] || continue
        case "$backup_file" in
            *.meta) continue ;;
        esac
        base_name=$(basename "$backup_file")
        # Skip SUID binary backups — they use a different naming scheme
        case "$base_name" in
            _usr_bin_*|_usr_sbin_*|_bin_*|_sbin_*) continue ;;
        esac
        target_file=$(echo "$base_name" | tr '_' '/')
        cp -a "$backup_file" "$target_file" 2>/dev/null || true
    done

    # Restore modes / owners / groups from .meta files
    for meta_file in "$BACKUP_DIR"/*.meta; do
        [ -f "$meta_file" ] || continue
        base_name=$(basename "$meta_file" .meta)
        target_file=$(echo "$base_name" | tr '_' '/')
        if [ -e "$target_file" ]; then
            read -r mode owner group < "$meta_file"
            chmod "$mode" "$target_file" 2>/dev/null || true
            chown "${owner}:${group}" "$target_file" 2>/dev/null || true
        fi
    done

    rm -rf "$BACKUP_DIR"
fi

# ── Remove SUID bit that unsecure may have added ──
if [ -f "/usr/bin/cp" ]; then
    chmod u-s /usr/bin/cp 2>/dev/null || true
fi

echo "Restore completed successfully."