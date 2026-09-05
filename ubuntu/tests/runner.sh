#!/usr/bin/env bash

# ==============================================================================
# Beetle Detailed Test Harness (Script-by-Script Audit & Verification)
# Runs per-script checks:
# 1. Capture clean state
# 2. Run unsecure script
# 3. Run audit -> compare Actual vs Expected ("NOT HARDENED")
# 4. Run harden script
# 5. Run audit -> compare Actual vs Expected ("HARDENED")
# 6. Print script-by-script table with NAME, Filename, Actual vs Expected
# 7. Restore system state
# ==============================================================================

set -euo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BEETLE_SHELL_DIR="$(cd "$TEST_DIR/../beetle_shell" && pwd)"

source "$TEST_DIR/helpers/test_lib.sh"
source "$TEST_DIR/helpers/system_sandbox.sh"

# Source Beetle environment stores so standalone audit scripts can read RAM stores/configs
export BEETLE_SHELL_ROOT="$BEETLE_SHELL_DIR"
source "$BEETLE_SHELL_DIR/lib/ram_store.sh" 2>/dev/null || true
source "$BEETLE_SHELL_DIR/lib/find_json.sh" 2>/dev/null || true

load_dpkg 2>/dev/null || true
load_severity "basic" 2>/dev/null || true

if [ "$EUID" -ne 0 ]; then
    log_failure "Test runner requires root permissions (sudo)."
    exit 1
fi

log_section "BEETLE SCRIPT-BY-SCRIPT VERIFICATION TEST HARNESS"

# Always restore clean system state on exit
cleanup_and_restore() {
    log_section "CLEANUP & RESTORATION"
    system_snapshot_restore
    system_snapshot_cleanup
    unload_all 2>/dev/null || true
}
trap cleanup_and_restore EXIT

# Step 1: Create snapshot
log_section "STEP 1: CREATING SYSTEM SNAPSHOT"
system_snapshot_create

# Step 2: Unsecure system
log_section "STEP 2: UNSECURING SYSTEM CONFIGURATIONS"
bash "$TEST_DIR/unsecure/unsecure_all.sh"

# Function to run audit on a single script file with RAM store / JSON pre-loaded
run_single_audit_script() {
    local script_path="$1"
    local script_name
    script_name=$(awk -F= '/^NAME=/{gsub(/"/,"",$2); print $2}' "$script_path" 2>/dev/null || echo "")
    [ -z "$script_name" ] && script_name="$(basename "$script_path")"

    # Pre-load JSON module RAM store if script requires one (e.g. PERM_RAM_STORE)
    local module_json json_type json_file
    module_json=$(find_module_json "$script_path" 2>/dev/null || echo "")
    if [ -n "$module_json" ]; then
        json_type="${module_json%%::*}"
        json_file="${module_json##*::}"
        load_module_json "$json_type" "$json_file" 2>/dev/null || true
    fi

    export PERM_RAM_STORE DPKG_RAM_STORE SEVERITY_RAM_STORE NETWORK_RAM_STORE SERVICES_RAM_STORE ACCESS_RAM_STORE FW_RAM_STORE LOGGING_RAM_STORE INITIAL_SETUP_RAM_STORE

    local output
    output=$(bash "$script_path" 2>/dev/null || echo "ERROR")
    output=$(echo "$output" | tr -d '\r\n')

    # Unload module JSON if loaded
    [ -n "$module_json" ] && unload_module_json "$json_type" 2>/dev/null || true

    local status="UNKNOWN"
    if [[ "$output" == *"NOT HARDENED"* ]]; then
        status="NOT HARDENED"
    elif [[ "$output" == *"HARDENED"* ]]; then
        status="HARDENED"
    else
        status="ERROR"
    fi

    # Escape pipe symbols in name if any
    script_name="${script_name//|/-}"
    echo "$script_name|$status"
}

# Determine target audit directory (Filter to system_maintenance if only unsecuring system_maintenance)
AUDIT_TARGET_DIR="$BEETLE_SHELL_DIR/audit"
if [ -d "$TEST_DIR/unsecure/system_maintenance" ] && [ ! -d "$TEST_DIR/unsecure/access_control" ]; then
    AUDIT_TARGET_DIR="$BEETLE_SHELL_DIR/audit/system_maintenance"
fi

mapfile -t audit_scripts < <(find "$AUDIT_TARGET_DIR" -type f -name "*.sh" | sort)

# Step 3: Run Script-by-Script Unsecure Audit Test
log_section "STEP 3: AUDITING UNSECURED STATE (EXPECTED: NOT HARDENED)"

echo "-----------------------------------------------------------------------------------------------------------------------------"
printf "%-40s | %-45s | %-13s | %-13s | %-6s\n" "FILE / MODULE" "CHECK NAME" "EXPECTED" "ACTUAL" "RESULT"
echo "-----------------------------------------------------------------------------------------------------------------------------"

UNSECURE_PASS=0
UNSECURE_FAIL=0

for script in "${audit_scripts[@]}"; do
    rel_path="${script#$BEETLE_SHELL_DIR/audit/}"
    res=$(run_single_audit_script "$script")
    name="${res%%|*}"
    actual="${res##*|}"
    
    expected="NOT HARDENED"
    
    if [ "$actual" == "$expected" ]; then
        result_color="${COLOR_GREEN}PASS${COLOR_RESET}"
        UNSECURE_PASS=$((UNSECURE_PASS + 1))
    else
        result_color="${COLOR_YELLOW}INFO/FAIL${COLOR_RESET}"
        UNSECURE_FAIL=$((UNSECURE_FAIL + 1))
    fi

    printf "%-40s | %-45s | %-13s | %-13s | %b\n" "${rel_path:0:40}" "${name:0:45}" "$expected" "$actual" "$result_color"
done

# Step 4: Run Harden
log_section "STEP 4: HARDENING SYSTEM"
if [ "$AUDIT_TARGET_DIR" != "$BEETLE_SHELL_DIR/audit" ]; then
    bash "$BEETLE_SHELL_DIR/harden.sh" system_maintenance || true
else
    bash "$BEETLE_SHELL_DIR/harden.sh" || true
fi

# Step 5: Run Script-by-Script Post-Harden Audit Test
log_section "STEP 5: AUDITING HARDENED STATE (EXPECTED: HARDENED)"

echo "-----------------------------------------------------------------------------------------------------------------------------"
printf "%-40s | %-45s | %-13s | %-13s | %-6s\n" "FILE / MODULE" "CHECK NAME" "EXPECTED" "ACTUAL" "RESULT"
echo "-----------------------------------------------------------------------------------------------------------------------------"

HARDEN_PASS=0
HARDEN_FAIL=0

for script in "${audit_scripts[@]}"; do
    rel_path="${script#$BEETLE_SHELL_DIR/audit/}"
    res=$(run_single_audit_script "$script")
    name="${res%%|*}"
    actual="${res##*|}"
    expected="HARDENED"

    if [ "$actual" == "$expected" ]; then
        result_color="${COLOR_GREEN}PASS${COLOR_RESET}"
        HARDEN_PASS=$((HARDEN_PASS + 1))
    else
        result_color="${COLOR_RED}FAIL${COLOR_RESET}"
        HARDEN_FAIL=$((HARDEN_FAIL + 1))
    fi

    printf "%-40s | %-45s | %-13s | %-13s | %b\n" "${rel_path:0:40}" "${name:0:45}" "$expected" "$actual" "$result_color"
done

log_section "TEST SUMMARY"
echo -e "Unsecure State Checks : ${COLOR_GREEN}${UNSECURE_PASS} Detected Unhardened${COLOR_RESET}"
echo -e "Post-Harden Checks    : ${COLOR_GREEN}${HARDEN_PASS} Passed (HARDENED)${COLOR_RESET}, ${COLOR_RED}${HARDEN_FAIL} Failed${COLOR_RESET}"
