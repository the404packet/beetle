#!/usr/bin/env bash
# run_test.sh - Automated test runner for Beetle access_control module
# Workflow:
# 1. Load dependencies & unsecure all settings
# 2. Run Beetle Audit (Expected: NOT HARDENED, Actual: verified)
# 3. Run Beetle Harden non-interactively
# 4. Run Beetle Audit again (Expected: HARDENED, Actual: verified)
# 5. Output real-time progress and summary results table
# 6. Restore original system state from backup

set -uo pipefail
# Note: NOT using -e globally so individual script failures don't abort the runner.

# Ensure non-interactive execution for all sub-tools & package managers
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a
export PAM_AUTH_UPDATE_NO_PROMPT=1

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
echo -e "${CYAN}      Beetle Access Control Test Suite Runner       ${RESET}"
echo -e "${CYAN}====================================================${RESET}\n"

# Step 1: Unsecure settings (backup first, then weaken)
echo -e "${YELLOW}[STEP 1] Unsecuring all access_control settings...${RESET}"
bash "$UNSECURE_SCRIPT"

# Step 2: Load environment dependencies so RAM stores are populated for harden/audit scripts
load_dpkg
load_severity "strict"
load_json_access_control "$SCRIPT_DIR/../../config/access_control.json"

export DPKG_RAM_STORE PERM_RAM_STORE SEVERITY_RAM_STORE SSH_RAM_STORE

# Find all audit scripts under access_control
mapfile -d '' AUDIT_SCRIPTS < <(
    find "$BEETLE_SHELL_ROOT/audit/access_control" \
        -mindepth 1 -type f -name "*.sh" -print0 | sort -z
)

# Phase 1 Audit Results Data Structures
declare -A SCRIPT_NAMES
declare -A INITIAL_ACTUAL
declare -A INITIAL_STATUS

echo -e "\n${YELLOW}[STEP 2] Running Initial Audit (Expected: NOT HARDENED)...${RESET}"

for script in "${AUDIT_SCRIPTS[@]}"; do
    rel_path="${script#$BEETLE_SHELL_ROOT/audit/access_control/}"
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

# Step 3: Run Beetle Harden for access_control
echo -e "\n${YELLOW}[STEP 3] Running Beetle Harden for access_control...${RESET}"

mapfile -d '' HARDEN_SCRIPTS < <(
    find "$BEETLE_SHELL_ROOT/harden/access_control" \
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
    DEBIAN_FRONTEND=noninteractive PAM_AUTH_UPDATE_NO_PROMPT=1 \
        bash "$script" < /dev/null > "$TMP_FILE" 2>&1 || true
    harden_res=$(tr -d '\r' < "$TMP_FILE" | tr '\n' ' ' | xargs)
    rm -f "$TMP_FILE"

    if [[ "$harden_res" == *"SUCCESS"* || "$harden_res" == *"HARDENED"* ]]; then
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
    rel_path="${script#$BEETLE_SHELL_ROOT/audit/access_control/}"
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

# Summary Table
echo -e "\n${CYAN}========================================================================================${RESET}"
echo -e "${CYAN}                            TEST SUMMARY RESULTS TABLE                                  ${RESET}"
echo -e "${CYAN}========================================================================================${RESET}"
printf "%-48s | %-15s | %-15s | %-8s\n" "Script Name" "Initial Audit" "Final Audit" "Result"
echo -e "----------------------------------------------------------------------------------------"
pass_count=0
fail_count=0
total_count=0
for script in "${AUDIT_SCRIPTS[@]}"; do
    rel_path="${script#$BEETLE_SHELL_ROOT/audit/access_control/}"
    script_id="${rel_path%.sh}"
    name="${SCRIPT_NAMES[$script_id]}"
    init="${INITIAL_ACTUAL[$script_id]}"
    fin="${FINAL_ACTUAL[$script_id]}"

    total_count=$((total_count + 1))
    if [[ "${INITIAL_STATUS[$script_id]}" == "PASS" && "${FINAL_STATUS[$script_id]}" == "PASS" ]]; then
        res_str="PASS"
        res_color="${GREEN}"
        pass_count=$((pass_count + 1))
    else
        res_str="FAIL"
        res_color="${RED}"
        fail_count=$((fail_count + 1))
    fi
    printf "%-48s | %-15s | %-15s | ${res_color}%-8s${RESET}\n" "$name" "$init" "$fin" "$res_str"
done
echo -e "----------------------------------------------------------------------------------------"
echo -e "Total Checks: $total_count | ${GREEN}Passed: $pass_count${RESET} | ${RED}Failed: $fail_count${RESET}"
echo -e "${CYAN}========================================================================================${RESET}"
