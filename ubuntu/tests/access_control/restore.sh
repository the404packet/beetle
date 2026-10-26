#!/usr/bin/env bash
# restore.sh - Restores settings from /tmp/beetle_access_control_backup and cleans up test entries.

set -e

BACKUP_DIR="/tmp/beetle_access_control_backup"

echo "=== Cleaning up test accounts/files created during unsecure ==="
userdel -f unsecure_acc_user 2>/dev/null || true
userdel -f unsecure_uid0 2>/dev/null || true
userdel -f unsecure_gid0 2>/dev/null || true
userdel -f unsecure_sys 2>/dev/null || true
userdel -f unsecure_nologin_unlocked 2>/dev/null || true
groupdel unsecure_grp0 2>/dev/null || true

sed -i '/^unsecure_/d' /etc/passwd 2>/dev/null || true
sed -i '/^unsecure_/d' /etc/group 2>/dev/null || true
sed -i '/^unsecure_/d' /etc/shadow 2>/dev/null || true

rm -f /etc/profile.d/50-systemwide_tmout.sh
rm -f /etc/profile.d/50-systemwide_umask.sh
rm -f /var/log/sudo.log

if [ -d "$BACKUP_DIR" ]; then
    echo "=== Restoring backed up directory structures ==="
    # Directories backed up as <backup>/<safe_d>_dir/ with a <safe_d>_dir.path sidecar
    for dir_path_file in "$BACKUP_DIR"/*_dir.path; do
        [ -f "$dir_path_file" ] || continue
        target_d=$(cat "$dir_path_file")
        base_d=$(basename "$dir_path_file" .path)
        dir_meta="$BACKUP_DIR/${base_d}.meta"

        if [ -d "$BACKUP_DIR/$base_d" ]; then
            rm -rf "$target_d"
            cp -rP "$BACKUP_DIR/$base_d" "$target_d"
        fi

        if [ -e "$target_d" ] && [ -f "$dir_meta" ]; then
            read -r mode owner group < "$dir_meta"
            chmod "$mode" "$target_d" 2>/dev/null || true
            chown "${owner}:${group}" "$target_d" 2>/dev/null || true
        fi
    done

    echo "=== Restoring backed up system files & permissions ==="
    # Files backed up as <backup>/<safe_name> with a <safe_name>.path sidecar
    for path_file in "$BACKUP_DIR"/*.path; do
        [ -f "$path_file" ] || continue
        [[ "$path_file" == *"_dir.path" ]] && continue
        base_name=$(basename "$path_file" .path)
        target_file=$(cat "$path_file")
        meta_file="$BACKUP_DIR/${base_name}.meta"

        # Restore backed up file content if file backup exists
        if [ -f "$BACKUP_DIR/$base_name" ]; then
            # Ensure parent directory exists
            mkdir -p "$(dirname "$target_file")"
            cp -a "$BACKUP_DIR/$base_name" "$target_file"
        fi

        # Restore original mode, owner, group
        if [ -e "$target_file" ] && [ -f "$meta_file" ]; then
            read -r mode owner group < "$meta_file"
            chmod "$mode" "$target_file" 2>/dev/null || true
            chown "${owner}:${group}" "$target_file" 2>/dev/null || true
        fi
    done

    # Restore Services Status (ssh, sshd)
    if [ -f "$BACKUP_DIR/services.status" ]; then
        echo "=== Restoring services status ==="
        while read -r s status active; do
            [ -z "$s" ] && continue
            if [ "$status" = "enabled" ]; then
                systemctl enable "$s" 2>/dev/null || true
            elif [ "$status" = "disabled" ]; then
                systemctl disable "$s" 2>/dev/null || true
            fi
            if [ "$active" = "active" ]; then
                systemctl start "$s" 2>/dev/null || true
            elif [ "$active" = "inactive" ]; then
                systemctl stop "$s" 2>/dev/null || true
            fi
        done < "$BACKUP_DIR/services.status"
    fi

    # Restore Firewall Rules
    if [ -f "$BACKUP_DIR/iptables.rules" ] && command -v iptables-restore &>/dev/null; then
        iptables-restore < "$BACKUP_DIR/iptables.rules" 2>/dev/null || true
    fi

    # Cleanup backup directory
    rm -rf "$BACKUP_DIR"
fi

echo "Restore completed successfully."
