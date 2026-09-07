#!/usr/bin/env bash
# run_test.sh - Automated test runner for Beetle system_maintenance module
# Workflow:
# 1. Store backup & Unsecure all settings
# 2. Run Beetle Audit (Expected: NOT HARDENED, Actual: verified)
# 3. Run Beetle Harden
# 4. Run Beetle Audit again (Expected: HARDENED, Actual: verified)
# 5. Output comparison table with NAME variable, expected state, and actual state
# 6. Restore original system state from backup

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BEETLE_SHELL_ROOT="$(cd "$SCRIPT_DIR/../../beetle_shell" && pwd)"
export BEETLE_SHELL_ROOT
export SKIP_SNAPSHOT="true"

UNSECURE_SCRIPT="$SCRIPT_DIR/unsecure.sh"
RESTORE_SCRIPT="$SCRIPT_DIR/restore.sh"

LIB_DIR="$BEETLE_SHELL_ROOT/lib"
source "$LIB_DIR/ram_store.sh"  || { echo "ERROR: cannot load ram_store.sh"; exit 1; }
source "$LIB_DIR/find_json.sh"  || { echo "ERROR: cannot load find_json.sh"; exit 1; }

GREEN="\e[32m"
RED="\e[31m"
CYAN="\e[36m"
YELLOW="\e[33m"
RESET="\e[0m"

cleanup() {
    echo -e "\n${CYAN}=== Restoring original system state ===${RESET}"
    bash "$RESTORE_SCRIPT" || true
    unload_all || true
}
trap cleanup EXIT

echo -e "${CYAN}====================================================${RESET}"
echo -e "${CYAN}   Beetle System Maintenance Test Suite Runner       ${RESET}"
echo -e "${CYAN}====================================================${RESET}\n"

# Step 1: Unsecure settings
echo -e "${YELLOW}[STEP 1] Unsecuring all system_maintenance settings...${RESET}"
bash "$UNSECURE_SCRIPT"

# Load environment dependencies for running audit & harden scripts
load_dpkg
load_severity "strict"
load_json_system_maintenance "$SCRIPT_DIR/../../config/system_maintenance.json"

export DPKG_RAM_STORE PERM_RAM_STORE SEVERITY_RAM_STORE

# Find all audit scripts under system_maintenance
mapfile -d '' AUDIT_SCRIPTS < <(
    find "$BEETLE_SHELL_ROOT/audit/system_maintenance" \
        -mindepth 1 -type f -name "*.sh" -print0 | sort -z
)

# Phase 1 Audit Results Data Structures
declare -A SCRIPT_NAMES
declare -A INITIAL_ACTUAL
declare -A INITIAL_STATUS

echo -e "\n${YELLOW}[STEP 2] Running Initial Audit (Expected: NOT HARDENED)...${RESET}"

for script in "${AUDIT_SCRIPTS[@]}"; do
    rel_path="${script#$BEETLE_SHELL_ROOT/audit/system_maintenance/}"
    script_id="${rel_path%.sh}"

    name=$(awk -F= '/^NAME=/{gsub(/"/,"",$2); print $2}' "$script")
    [ -z "$name" ] && name="$(basename "$script")"
    SCRIPT_NAMES["$script_id"]="$name"

    TMP_FILE=$(mktemp)
    bash "$script" > "$TMP_FILE" 2>/dev/null || true
    raw_res=$(tr -d '\r' < "$TMP_FILE" | tr '\n' ' ' | xargs)
    rm -f "$TMP_FILE"

    if [[ "$raw_res" == *"HARDENED"* && "$raw_res" != *"NOT HARDENED"* ]]; then
        ACTUAL="HARDENED"
        STATUS="FAIL (Unexpected HARDENED)"
        COLOR="${RED}"
    elif [[ "$raw_res" == *"NOT HARDENED"* ]]; then
        ACTUAL="NOT HARDENED"
        STATUS="PASS"
        COLOR="${GREEN}"
    else
        ACTUAL="UNKNOWN / ERROR"
        STATUS="FAIL"
        COLOR="${RED}"
    fi

    INITIAL_ACTUAL["$script_id"]="$ACTUAL"
    INITIAL_STATUS["$script_id"]="$STATUS"

    printf "  Audit: %-48s | Expected: %-12s | Actual: ${COLOR}%-12s${RESET} | Status: ${COLOR}%s${RESET}\n" \
        "$name" "NOT HARDENED" "$ACTUAL" "$STATUS"
done

# Step 3: Run Beetle Harden for system_maintenance
echo -e "\n${YELLOW}[STEP 3] Running Beetle Harden for system_maintenance...${RESET}"
mapfile -d '' HARDEN_SCRIPTS < <(
    find "$BEETLE_SHELL_ROOT/harden/system_maintenance" \
        -mindepth 1 -type f -name "*.sh" -print0 | sort -z
)

for script in "${HARDEN_SCRIPTS[@]}"; do
    name=$(awk -F= '/^NAME=/{gsub(/"/,"",$2); print $2}' "$script")
    [ -z "$name" ] && name="$(basename "$script")"
    
    # Check if script reads from /dev/tty directly (interactive prompt that hangs non-interactive runners)
    if grep -q '/dev/tty' "$script"; then
        printf "  Harden: %-47s | Result: ${YELLOW}%s${RESET}\n" "$name" "SKIPPED (Interactive)"
        continue
    fi

    TMP_FILE=$(mktemp)
    # Pass empty line for default choices
    echo "" | bash "$script" > "$TMP_FILE" 2>/dev/null || true
    harden_res=$(tr -d '\r' < "$TMP_FILE" | tr '\n' ' ' | xargs)
    rm -f "$TMP_FILE"
    
    if [[ "$harden_res" == *"SUCCESS"* ]]; then
        printf "  Harden: %-47s | Result: ${GREEN}%s${RESET}\n" "$name" "SUCCESS"
    else
        printf "  Harden: %-47s | Result: ${RED}%s${RESET}\n" "$name" "FAILED"
    fi
done

# Step 4: Run Final Audit (Expected: HARDENED)
echo -e "\n${YELLOW}[STEP 4] Running Final Audit after Hardening (Expected: HARDENED)...${RESET}"

declare -A FINAL_ACTUAL
declare -A FINAL_STATUS

for script in "${AUDIT_SCRIPTS[@]}"; do
    rel_path="${script#$BEETLE_SHELL_ROOT/audit/system_maintenance/}"
    script_id="${rel_path%.sh}"
    name="${SCRIPT_NAMES[$script_id]}"

    TMP_FILE=$(mktemp)
    bash "$script" > "$TMP_FILE" 2>/dev/null || true
    raw_res=$(tr -d '\r' < "$TMP_FILE" | tr '\n' ' ' | xargs)
    rm -f "$TMP_FILE"

    if [[ "$raw_res" == *"HARDENED"* && "$raw_res" != *"NOT HARDENED"* ]]; then
        ACTUAL="HARDENED"
        STATUS="PASS"
        COLOR="${GREEN}"
    elif [[ "$raw_res" == *"NOT HARDENED"* ]]; then
        ACTUAL="NOT HARDENED"
        STATUS="FAIL"
        COLOR="${RED}"
    else
        ACTUAL="UNKNOWN / ERROR"
        STATUS="FAIL"
        COLOR="${RED}"
    fi

    FINAL_ACTUAL["$script_id"]="$ACTUAL"
    FINAL_STATUS["$script_id"]="$STATUS"

    printf "  Audit: %-48s | Expected: %-12s | Actual: ${COLOR}%-12s${RESET} | Status: ${COLOR}%s${RESET}\n" \
        "$name" "HARDENED" "$ACTUAL" "$STATUS"
done

