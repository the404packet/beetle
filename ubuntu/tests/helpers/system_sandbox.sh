#!/usr/bin/env bash

# ==============================================================================
# Beetle System Isolation Sandbox Helper
# Targeted lightweight backup & restoration of system security configurations
# Works on: WSL2, Ubuntu Bare-Metal, Ubuntu VMs, Cloud Instances
# ==============================================================================

BACKUP_FILE="/tmp/beetle_test_clean_snapshot.tar.gz"

system_snapshot_create() {
    echo "[Sandbox] Creating targeted system snapshot in $BACKUP_FILE..."

    # Ensure running as root
    if [ "$EUID" -ne 0 ]; then
        echo "[Sandbox Error] Snapshot creation requires root privileges (sudo)"
        exit 1
    fi

    # Target directories critical for security audit/hardening
    local TARGETS=(
        "/etc/pam.d"
        "/etc/security"
        "/etc/ssh"
        "/etc/sysctl.d"
        "/etc/sysctl.conf"
        "/etc/ufw"
        "/etc/audit"
        "/etc/rsyslog.conf"
        "/etc/rsyslog.d"
        "/etc/systemd/system"
        "/etc/issue"
        "/etc/issue.net"
        "/etc/motd"
        "/etc/shadow"
        "/etc/gshadow"
        "/etc/passwd"
        "/etc/group"
        "/etc/shells"
    )

    local EXISTING_TARGETS=()
    for target in "${TARGETS[@]}"; do
        if [ -e "$target" ]; then
            EXISTING_TARGETS+=("$target")
        fi
    done

    tar --same-owner -p -czf "$BACKUP_FILE" "${EXISTING_TARGETS[@]}" 2>/dev/null || {
        echo "[Sandbox Error] Failed to create snapshot tar archive"
        exit 1
    }

    echo "[Sandbox] System snapshot created successfully ($(du -h "$BACKUP_FILE" | cut -f1))"
}

system_snapshot_restore() {
    echo "[Sandbox] Restoring system configuration from $BACKUP_FILE..."

    if [ "$EUID" -ne 0 ]; then
        echo "[Sandbox Error] Snapshot restoration requires root privileges (sudo)"
        exit 1
    fi

    if [ ! -f "$BACKUP_FILE" ]; then
        echo "[Sandbox Error] Snapshot file $BACKUP_FILE not found!"
        exit 1
    fi

    tar --same-owner -p -xzf "$BACKUP_FILE" -C / 2>/dev/null || {
        echo "[Sandbox Error] Failed to restore snapshot archive"
        exit 1
    }

    # Reload system sub-components safely
    sysctl --system >/dev/null 2>&1 || true
    if command -v ufw >/dev/null 2>&1; then
        ufw reload >/dev/null 2>&1 || true
    fi
    systemctl daemon-reload >/dev/null 2>&1 || true

    echo "[Sandbox] System configuration restored to clean state!"
}

system_snapshot_cleanup() {
    if [ -f "$BACKUP_FILE" ]; then
        rm -f "$BACKUP_FILE"
        echo "[Sandbox] Cleaned up temporary snapshot archive."
    fi
}
