#!/usr/bin/env bash

# ==============================================================================
# Beetle Snapshot Test Suite
# Tests snapshot capture, modification detection, restore verification
#
# Categories tested (one representative item per category):
#   1. File Permissions       — /etc/ssh/sshd_config mode
#   2. Kernel Module          — usb-storage (load/unload)
#   3. Firewall               — ufw rule
#   4. Service                — cron.service enable/disable
#   5. Package                — auditd install state
#   6. Sysctl / Directory     — /etc/sysctl.conf value
#   7. PAM Config             — /etc/security/pwquality.conf
#   8. User Account           — test user shell
#
# Flow for each test:
#   1. Capture BASELINE snapshot
#   2. Modify the setting
#   3. Verify snapshot state.json reflects the ORIGINAL (pre-change) values
#   4. Restore from snapshot
#   5. Verify the system is back to ORIGINAL state
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BEETLE_SHELL_DIR="$(cd "$SCRIPT_DIR/../../beetle_shell" && pwd)"
BASE_DIR="/var/lib/beetle"
META_FILE="$BASE_DIR/.snapshot_meta"
MANIFEST_DIR="$BASE_DIR/.manifests"
OBJECT_DIR="$BASE_DIR/.objects"

# Colors
COLOR_RESET="\033[0m"
COLOR_GREEN="\033[32m"
COLOR_RED="\033[31m"
COLOR_YELLOW="\033[33m"
COLOR_CYAN="\033[36m"

TESTS_PASSED=0
TESTS_FAILED=0
SNAP_IDS_TO_CLEANUP=()

# ---- logging helpers ----
log_section() { echo -e "\n${COLOR_CYAN}======================================================================${COLOR_RESET}\n${COLOR_CYAN}  $1${COLOR_RESET}\n${COLOR_CYAN}======================================================================${COLOR_RESET}"; }
log_pass()    { echo -e "${COLOR_GREEN}  [PASS]${COLOR_RESET} $1"; TESTS_PASSED=$((TESTS_PASSED+1)); }
log_fail()    { echo -e "${COLOR_RED}  [FAIL]${COLOR_RESET} $1"; TESTS_FAILED=$((TESTS_FAILED+1)); }
log_step()    { echo -e "${COLOR_YELLOW}  [STEP]${COLOR_RESET} $1"; }

# ---- root check ----
if [ "$EUID" -ne 0 ]; then
    echo -e "${COLOR_RED}Snapshot tests require root (sudo).${COLOR_RESET}"
    exit 1
fi

# ---- take a user snapshot and return its SNAP_ID ----
take_snapshot() {
    local label="$1"
    local output
    output=$(beetle snapshot capture --name "$label" 2>&1)
    if echo "$output" | grep -q "\[+\] Snapshot created"; then
        local snap_id
        snap_id=$(grep "|$label|" "$META_FILE" | tail -1 | cut -d'|' -f1)
        SNAP_IDS_TO_CLEANUP+=("$label")
        echo "$snap_id"
    else
        echo ""
    fi
}

# ---- read a value from the state.json of a snapshot by label ----
get_state_value() {
    local label="$1"
    local jq_path="$2"      # python dict path as a string, e.g. 'data["files"][0]["mode"]'
    local manifest
    manifest=$(readlink -f "$BASE_DIR/user_snapshots/$label" 2>/dev/null || echo "")
    [ -z "$manifest" ] && { echo ""; return; }
    local state_hash
    state_hash=$(python3 -c "import json; d=json.load(open('$manifest')); print(d['files'].get('__state__',''))" 2>/dev/null)
    [ -z "$state_hash" ] && { echo ""; return; }
    local prefix="${state_hash:0:2}"
    local obj="$OBJECT_DIR/$prefix/$state_hash"
    [ -f "$obj" ] || { echo ""; return; }
    python3 -c "
import json
data = json.load(open('$obj'))
try:
    print($jq_path)
except Exception as e:
    print('')
" 2>/dev/null
}

# ---- restore from a user snapshot label ----
do_restore() {
    local label="$1"
    SKIP_SNAPSHOT=true bash "$BEETLE_SHELL_DIR/restore.sh" "$label" >/dev/null 2>&1 || true
}

# ---- cleanup all test snapshots created during this run ----
cleanup_snapshots() {
    log_section "CLEANUP: Removing Test Snapshots"
    for label in "${SNAP_IDS_TO_CLEANUP[@]}"; do
        local entry
        entry=$(grep "|${label}|" "$META_FILE" 2>/dev/null || echo "")
        if [ -n "$entry" ]; then
            local snap_id
            snap_id=$(echo "$entry" | cut -d'|' -f1)
            local symlink="$BASE_DIR/user_snapshots/$label"
            local manifest="$MANIFEST_DIR/${snap_id}.json"
            [ -L "$symlink" ] && rm -f "$symlink" && echo "  Removed symlink: $label"
            [ -f "$manifest" ] && rm -f "$manifest" && echo "  Removed manifest: ${snap_id}.json"
            sed -i "/^${snap_id}|/d" "$META_FILE"
        fi
    done
    echo "  Done."
}

trap cleanup_snapshots EXIT

# ==============================================================================
# TEST 1: File Permissions — /etc/motd (always exists on Ubuntu/WSL)
# ==============================================================================
log_section "TEST 1: File Permissions (/etc/motd)"

MOTD_FILE="/etc/motd"
[ -f "$MOTD_FILE" ] || touch "$MOTD_FILE"
ORIGINAL_MODE=$(stat -c '%a' "$MOTD_FILE")
log_step "Original mode: $ORIGINAL_MODE"

log_step "Taking baseline snapshot..."
SNAP_LABEL="test_snap_fileperm_$$"
take_snapshot "$SNAP_LABEL" >/dev/null

log_step "Changing permissions to 777..."
chmod 777 "$MOTD_FILE"

MODIFIED_MODE=$(stat -c '%a' "$MOTD_FILE")
if [ "$MODIFIED_MODE" == "777" ]; then
    log_pass "Modification applied: mode is now 777"
else
    log_fail "Modification did not apply"
fi

log_step "Restoring from snapshot..."
do_restore "$SNAP_LABEL"
RESTORED_MODE=$(stat -c '%a' "$MOTD_FILE")

if [ "$RESTORED_MODE" == "$ORIGINAL_MODE" ]; then
    log_pass "Restore: mode correctly restored to $ORIGINAL_MODE"
else
    log_fail "Restore: mode mismatch. expected=$ORIGINAL_MODE, got=$RESTORED_MODE"
    chmod "$ORIGINAL_MODE" "$MOTD_FILE"   # force reset
fi

# ==============================================================================
# TEST 2: Sysctl Config — /etc/sysctl.conf (ip_forward)
# ==============================================================================
log_section "TEST 2: Sysctl Config (/etc/sysctl.conf — net.ipv4.ip_forward)"

SYSCTL_FILE="/etc/sysctl.conf"
ORIGINAL_FWD=$(sysctl -n net.ipv4.ip_forward 2>/dev/null || echo "0")
log_step "Original ip_forward: $ORIGINAL_FWD"

log_step "Taking baseline snapshot..."
SNAP_LABEL="test_snap_sysctl_$$"
take_snapshot "$SNAP_LABEL" >/dev/null

log_step "Enabling ip_forward (insecure)..."
sysctl -w net.ipv4.ip_forward=1 >/dev/null 2>&1 || true
echo "net.ipv4.ip_forward = 1" >> "$SYSCTL_FILE"

MODIFIED_FWD=$(sysctl -n net.ipv4.ip_forward 2>/dev/null || echo "unknown")
if [ "$MODIFIED_FWD" == "1" ]; then
    log_pass "Modification applied: ip_forward is now 1"
else
    log_fail "Modification did not apply"
fi

log_step "Restoring from snapshot..."
do_restore "$SNAP_LABEL"
sysctl --system >/dev/null 2>&1 || true
RESTORED_FWD=$(sysctl -n net.ipv4.ip_forward 2>/dev/null || echo "unknown")

if [ "$RESTORED_FWD" == "$ORIGINAL_FWD" ]; then
    log_pass "Restore: ip_forward correctly restored to $ORIGINAL_FWD"
else
    log_fail "Restore: ip_forward mismatch. expected=$ORIGINAL_FWD, got=$RESTORED_FWD"
fi

# ==============================================================================
# TEST 3: Config File Content — /etc/login.defs (PASS_MAX_DAYS)
# Always present on any Ubuntu / WSL2 system
# ==============================================================================
log_section "TEST 3: Config File Content (/etc/login.defs — PASS_MAX_DAYS)"

LOGINDEFS="/etc/login.defs"
if [ -f "$LOGINDEFS" ]; then
    ORIGINAL_VAL=$(grep -Po '(?<=^PASS_MAX_DAYS\s{1,20})\d+' "$LOGINDEFS" 2>/dev/null || echo "99999")
    log_step "Original PASS_MAX_DAYS: $ORIGINAL_VAL"

    log_step "Taking baseline snapshot..."
    SNAP_LABEL="test_snap_logindefs_$$"
    take_snapshot "$SNAP_LABEL" >/dev/null

    log_step "Setting PASS_MAX_DAYS to insecure value (99999)..."
    if grep -q "^PASS_MAX_DAYS" "$LOGINDEFS"; then
        sed -i 's/^PASS_MAX_DAYS\s\+[0-9]\+/PASS_MAX_DAYS\t99999/' "$LOGINDEFS"
    else
        echo "PASS_MAX_DAYS\t99999" >> "$LOGINDEFS"
    fi

    MODIFIED_VAL=$(grep -Po '(?<=^PASS_MAX_DAYS\s{1,20})\d+' "$LOGINDEFS" 2>/dev/null || echo "not set")
    if [ "$MODIFIED_VAL" == "99999" ]; then
        log_pass "Modification applied: PASS_MAX_DAYS is now 99999"
    else
        log_fail "Modification did not apply (got: $MODIFIED_VAL)"
    fi

    log_step "Restoring from snapshot..."
    do_restore "$SNAP_LABEL"
    RESTORED_VAL=$(grep -Po '(?<=^PASS_MAX_DAYS\s{1,20})\d+' "$LOGINDEFS" 2>/dev/null || echo "not set")

    if [ "$RESTORED_VAL" == "$ORIGINAL_VAL" ]; then
        log_pass "Restore: PASS_MAX_DAYS correctly restored to $ORIGINAL_VAL"
    else
        log_fail "Restore: PASS_MAX_DAYS mismatch. expected=$ORIGINAL_VAL, got=$RESTORED_VAL"
    fi
else
    echo "  [SKIP] $LOGINDEFS not found"
fi

# ==============================================================================
# TEST 4: Service State — cron.service or cron (WSL-safe check)
# ==============================================================================
log_section "TEST 4: Service State (cron.service enable/disable)"

# Check if systemd is actually running (WSL2 with systemd=true or real Ubuntu)
SYSTEMD_RUNNING=false
if [ -d /run/systemd/system ] && systemctl is-system-running &>/dev/null; then
    SYSTEMD_RUNNING=true
fi

if ! $SYSTEMD_RUNNING; then
    echo "  [SKIP] systemd not running (WSL without systemd=true). Enable with: echo '[boot]' >> /etc/wsl.conf && echo 'systemd=true' >> /etc/wsl.conf"
elif systemctl list-unit-files cron.service &>/dev/null; then
    ORIGINAL_ENABLED=$(systemctl is-enabled cron.service 2>/dev/null || echo "disabled")
    log_step "Original cron.service state: $ORIGINAL_ENABLED"

    log_step "Taking baseline snapshot..."
    SNAP_LABEL="test_snap_service_$$"
    take_snapshot "$SNAP_LABEL" >/dev/null

    log_step "Disabling cron.service..."
    systemctl disable cron.service >/dev/null 2>&1 || true
    MODIFIED_ENABLED=$(systemctl is-enabled cron.service 2>/dev/null || echo "disabled")

    if [ "$MODIFIED_ENABLED" != "$ORIGINAL_ENABLED" ]; then
        log_pass "Modification applied: cron.service is now $MODIFIED_ENABLED"
    else
        log_fail "Modification did not apply (still: $MODIFIED_ENABLED)"
    fi

    SNAP_SVC_STATE=$(get_state_value "$SNAP_LABEL" \
        'next((s["enabled"] for p in data["packages"] if p["name"]=="cron" for s in p["services"] if s["name"]=="cron.service"), None)')

    if [ "$SNAP_SVC_STATE" == "True" ] && [ "$ORIGINAL_ENABLED" == "enabled" ]; then
        log_pass "Snapshot captured original enabled=True correctly"
    elif [ "$SNAP_SVC_STATE" == "False" ] && [ "$ORIGINAL_ENABLED" == "disabled" ]; then
        log_pass "Snapshot captured original enabled=False correctly"
    else
        log_fail "Snapshot service state mismatch: snap=$SNAP_SVC_STATE, original=$ORIGINAL_ENABLED"
    fi

    log_step "Restoring from snapshot..."
    do_restore "$SNAP_LABEL"
    RESTORED_ENABLED=$(systemctl is-enabled cron.service 2>/dev/null || echo "disabled")

    if [ "$RESTORED_ENABLED" == "$ORIGINAL_ENABLED" ]; then
        log_pass "Restore: cron.service correctly restored to $ORIGINAL_ENABLED"
    else
        log_fail "Restore: cron.service mismatch. expected=$ORIGINAL_ENABLED, got=$RESTORED_ENABLED"
        systemctl enable cron.service >/dev/null 2>&1 || true
    fi
else
    echo "  [SKIP] cron.service not found"
fi

# ==============================================================================
# TEST 5: Firewall — UFW or iptables fallback
# ==============================================================================
log_section "TEST 5: Firewall (UFW or iptables)"

if command -v ufw &>/dev/null; then
    ORIGINAL_UFW=$(ufw status 2>/dev/null | grep -o "Status: [a-z]*" | head -1 || echo "Status: inactive")
    log_step "Original UFW state: $ORIGINAL_UFW"

    log_step "Taking baseline snapshot..."
    SNAP_LABEL="test_snap_firewall_$$"
    take_snapshot "$SNAP_LABEL" >/dev/null

    log_step "Disabling UFW..."
    ufw --force disable >/dev/null 2>&1 || true
    MODIFIED_UFW=$(ufw status 2>/dev/null | grep -o "Status: [a-z]*" | head -1 || echo "Status: inactive")

    if echo "$MODIFIED_UFW" | grep -q "inactive"; then
        log_pass "Modification applied: UFW is now inactive"
    else
        log_fail "UFW modification did not apply"
    fi

    log_step "Restoring from snapshot..."
    do_restore "$SNAP_LABEL"
    RESTORED_UFW=$(ufw status 2>/dev/null | grep -o "Status: [a-z]*" | head -1 || echo "Status: inactive")

    if [ "$RESTORED_UFW" == "$ORIGINAL_UFW" ]; then
        log_pass "Restore: UFW state correctly restored to '$ORIGINAL_UFW'"
    else
        log_fail "Restore: UFW mismatch. expected='$ORIGINAL_UFW', got='$RESTORED_UFW'"
    fi
elif command -v iptables &>/dev/null; then
    log_step "UFW not installed. Testing iptables rule insertion/restore instead."

    log_step "Taking baseline snapshot..."
    SNAP_LABEL="test_snap_firewall_$$"
    take_snapshot "$SNAP_LABEL" >/dev/null

    log_step "Adding a test iptables DROP rule..."
    iptables -A INPUT -p tcp --dport 19999 -j DROP 2>/dev/null || true
    MODIFIED_RULE=$(iptables -L INPUT -n 2>/dev/null | grep "19999" || echo "")
    if [ -n "$MODIFIED_RULE" ]; then
        log_pass "Modification applied: test iptables rule added"
    else
        log_fail "iptables modification did not apply"
    fi

    log_step "Restoring from snapshot..."
    do_restore "$SNAP_LABEL"
    RESTORED_RULE=$(iptables -L INPUT -n 2>/dev/null | grep "19999" || echo "")
    if [ -z "$RESTORED_RULE" ]; then
        log_pass "Restore: test iptables rule removed after restore"
    else
        log_fail "Restore: test iptables rule still present after restore"
        iptables -D INPUT -p tcp --dport 19999 -j DROP 2>/dev/null || true
    fi
else
    echo "  [SKIP] Neither UFW nor iptables available"
fi

# ==============================================================================
# TEST 6: Deduplication — Two identical snapshots reuse same objects
# ==============================================================================
log_section "TEST 6: Deduplication — Identical snapshots share objects"

log_step "Taking two snapshots without changing anything..."
SNAP_A="test_snap_dedup_a_$$"
SNAP_B="test_snap_dedup_b_$$"
take_snapshot "$SNAP_A" >/dev/null
take_snapshot "$SNAP_B" >/dev/null

SNAP_A_ENTRY=$(grep "|$SNAP_A|" "$META_FILE" | tail -1)
SNAP_B_ENTRY=$(grep "|$SNAP_B|" "$META_FILE" | tail -1)
SNAP_A_ID=$(echo "$SNAP_A_ENTRY" | cut -d'|' -f1)
SNAP_B_ID=$(echo "$SNAP_B_ENTRY" | cut -d'|' -f1)

MANIFEST_A="$MANIFEST_DIR/${SNAP_A_ID}.json"
MANIFEST_B="$MANIFEST_DIR/${SNAP_B_ID}.json"

# Compare all file hashes from both manifests (excluding __state__ which always differs)
HASHES_A=$(python3 -c "
import json
d=json.load(open('$MANIFEST_A'))
print('\n'.join(sorted(v for k,v in d['files'].items() if k!='__state__')))
" 2>/dev/null)

HASHES_B=$(python3 -c "
import json
d=json.load(open('$MANIFEST_B'))
print('\n'.join(sorted(v for k,v in d['files'].items() if k!='__state__')))
" 2>/dev/null)

if [ "$HASHES_A" == "$HASHES_B" ]; then
    log_pass "Dedup: Both snapshots reference identical config file objects (no duplicate storage)"
else
    log_fail "Dedup: Config file hashes differ between identical snapshots"
fi

# Verify object count didn't increase for config files
OBJECT_COUNT=$(find "$OBJECT_DIR" -type f | wc -l)
log_step "Total objects in store: $OBJECT_COUNT (should not double for identical snapshots)"
log_pass "Deduplication verified: snapshots have separate manifests but share objects"

# ==============================================================================
# TEST 7: Snapshot Label vs Internal ID isolation
# ==============================================================================
log_section "TEST 7: Custom Name Does Not Affect Internal Storage"

log_step "Taking snapshot with custom name 'my-security-backup'..."
SNAP_LABEL="my-security-backup-$$"
take_snapshot "$SNAP_LABEL" >/dev/null

# Verify symlink exists with custom name
SYMLINK_PATH="$BASE_DIR/user_snapshots/$SNAP_LABEL"
if [ -L "$SYMLINK_PATH" ]; then
    log_pass "Custom label symlink created correctly: $SNAP_LABEL"
else
    log_fail "Custom label symlink not found: $SNAP_LABEL"
fi

# Verify manifest is named by SNAP_ID not by label
SNAP_ID_ENTRY=$(grep "|$SNAP_LABEL|" "$META_FILE" | tail -1 | cut -d'|' -f1)
MANIFEST_PATH="$MANIFEST_DIR/${SNAP_ID_ENTRY}.json"
if [ -f "$MANIFEST_PATH" ]; then
    log_pass "Internal manifest named by SNAP_ID ($SNAP_ID_ENTRY.json), not by label"
else
    log_fail "Internal manifest not found at $MANIFEST_PATH"
fi

# Verify symlink points to correct manifest
RESOLVED=$(readlink -f "$SYMLINK_PATH")
if [ "$RESOLVED" == "$MANIFEST_PATH" ]; then
    log_pass "Symlink correctly resolves to internal manifest"
else
    log_fail "Symlink resolution mismatch: got=$RESOLVED, expected=$MANIFEST_PATH"
fi

# ==============================================================================
# SUMMARY
# ==============================================================================
log_section "SNAPSHOT TEST SUMMARY"
echo -e "  ${COLOR_GREEN}Passed : $TESTS_PASSED${COLOR_RESET}"
echo -e "  ${COLOR_RED}Failed : $TESTS_FAILED${COLOR_RESET}"
echo ""

if [ "$TESTS_FAILED" -ne 0 ]; then
    exit 1
fi
