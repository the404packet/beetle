#!/usr/bin/env bash
# run_test.sh - Automated test runner for Beetle logging_and_auditing module

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BEETLE_SHELL_ROOT="$(cd "$SCRIPT_DIR/../../beetle_shell" && pwd)"
export BEETLE_SHELL_ROOT
export SKIP_SNAPSHOT="true"

UNSECURE_SCRIPT="$SCRIPT_DIR/unsecure.sh"
RESTORE_SCRIPT="$SCRIPT_DIR/restore.sh"

LIB_DIR="$BEETLE_SHELL_ROOT/lib"
source "$LIB_DIR/ram_store.sh"  || { echo "ERROR: cannot load ram_store.sh"; exit 1; }
[ -f "$LIB_DIR/find_json.sh" ] && source "$LIB_DIR/find_json.sh" || true

GREEN="\e[32m"
RED="\e[31m"
CYAN="\e[36m"
YELLOW="\e[33m"
RESET="\e[0m"

cleanup() {
    echo -e "\n${CYAN}=== Restoring original system state ===${RESET}"
    bash "$RESTORE_SCRIPT" || true
    unload_all || true
    sudo rm -f /dev/shm/beetle_*.env 2>/dev/null || rm -f /dev/shm/beetle_*.env 2>/dev/null || true
}
trap cleanup EXIT

# Clean any stale ram stores from previous runs
sudo rm -f /dev/shm/beetle_*.env 2>/dev/null || rm -f /dev/shm/beetle_*.env 2>/dev/null || true

echo -e "${CYAN}====================================================${RESET}"
echo -e "${CYAN}   Beetle Logging & Auditing Test Suite Runner      ${RESET}"
echo -e "${CYAN}====================================================${RESET}\n"

# Step 1: Unsecure settings
echo -e "${YELLOW}[STEP 1] Unsecuring all logging_and_auditing settings...${RESET}"
bash "$UNSECURE_SCRIPT"

# Load environment dependencies (after unsecure, so package removals are seen)
load_dpkg
load_severity "strict"
load_json_logging_and_auditing "$SCRIPT_DIR/../../config/logging_and_auditing.json"

export DPKG_RAM_STORE LOGGING_RAM_STORE SEVERITY_RAM_STORE

mapfile -d '' AUDIT_SCRIPTS < <(
    find "$BEETLE_SHELL_ROOT/audit/logging_and_auditing" \
        -mindepth 1 -type f -name "*.sh" -print0 | sort -z
)

declare -A SCRIPT_NAMES
declare -A INITIAL_ACTUAL
declare -A INITIAL_STATUS

echo -e "\n${YELLOW}[STEP 2] Running Initial Audit (Expected: NOT HARDENED)...${RESET}"

for script in "${AUDIT_SCRIPTS[@]}"; do
    rel_path="${script#$BEETLE_SHELL_ROOT/audit/logging_and_auditing/}"
    script_id="${rel_path%.sh}"

    name=$(awk -F= '/^NAME=/{gsub(/["'"'"']/,"",$2); print $2}' "$script")
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

    printf "  Audit: %-52s | Expected: %-12s | Actual: ${COLOR}%-12s${RESET} | Status: ${COLOR}%s${RESET}\n" \
        "$name" "NOT HARDENED" "$ACTUAL" "$STATUS"
done

# Step 3: Harden
echo -e "\n${YELLOW}[STEP 3] Running Beetle Harden for logging_and_auditing...${RESET}"
mapfile -d '' HARDEN_SCRIPTS < <(
    find "$BEETLE_SHELL_ROOT/harden/logging_and_auditing" \
        -mindepth 1 -type f -name "*.sh" -print0 | sort -z
)

for script in "${HARDEN_SCRIPTS[@]}"; do
    name=$(awk -F= '/^NAME=/{gsub(/["'"'"']/,"",$2); print $2}' "$script")
    [ -z "$name" ] && name="$(basename "$script")"

    # Skip only scripts that read /dev/tty unconditionally
    if grep -q '/dev/tty' "$script" && ! grep -q '\[ -t 0 \]' "$script"; then
        printf "  Harden: %-51s | Result: ${YELLOW}%s${RESET}\n" "$name" "SKIPPED (Interactive)"
        continue
    fi

    TMP_FILE=$(mktemp)
    echo "" | bash "$script" > "$TMP_FILE" 2>/dev/null || true
    harden_res=$(tr -d '\r' < "$TMP_FILE" | tr '\n' ' ' | xargs)
    rm -f "$TMP_FILE"

    if [[ "$harden_res" == *"SUCCESS"* ]]; then
        printf "  Harden: %-51s | Result: ${GREEN}%s${RESET}\n" "$name" "SUCCESS"
    else
        printf "  Harden: %-51s | Result: ${RED}%s${RESET}\n" "$name" "FAILED"
    fi
done

# Step 3.5: Refresh ram store so Phase 4 sees post-harden state
echo -e "\n${YELLOW}[STEP 3.5] Refreshing ram store after harden...${RESET}"
load_dpkg
load_json_logging_and_auditing "$SCRIPT_DIR/../../config/logging_and_auditing.json"

# Step 4: Final Audit
echo -e "\n${YELLOW}[STEP 4] Running Final Audit after Hardening (Expected: HARDENED)...${RESET}"

declare -A FINAL_ACTUAL
declare -A FINAL_STATUS

for script in "${AUDIT_SCRIPTS[@]}"; do
    rel_path="${script#$BEETLE_SHELL_ROOT/audit/logging_and_auditing/}"
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

    printf "  Audit: %-52s | Expected: %-12s | Actual: ${COLOR}%-12s${RESET} | Status: ${COLOR}%s${RESET}\n" \
        "$name" "HARDENED" "$ACTUAL" "$STATUS"
done

# Step 5: Summary Table
echo -e "\n${CYAN}=========================================================================================================${RESET}"
echo -e "${CYAN}                                   LOGGING & AUDITING TEST RESULTS                                      ${RESET}"
echo -e "${CYAN}=========================================================================================================${RESET}"
printf "%-50s | %-15s | %-15s | %-15s | %-15s\n" "SCRIPT NAME (NAME variable)" "PHASE 1 EXP" "PHASE 1 ACT" "PHASE 2 EXP" "PHASE 2 ACT"
echo -e "---------------------------------------------------------------------------------------------------------"

for script_id in "${!SCRIPT_NAMES[@]}"; do
    name="${SCRIPT_NAMES[$script_id]}"
    p1_act="${INITIAL_ACTUAL[$script_id]}"
    p2_act="${FINAL_ACTUAL[$script_id]}"

    case "$p1_act" in
        "NOT HARDENED") p1_color="${GREEN}" ;;
        *)              p1_color="${RED}" ;;
    esac
    case "$p2_act" in
        "HARDENED") p2_color="${GREEN}" ;;
        *)          p2_color="${RED}" ;;
    esac

    printf "%-50s | %-15s | ${p1_color}%-15s${RESET} | %-15s | ${p2_color}%-15s${RESET}\n" \
        "$name" "NOT HARDENED" "$p1_act" "HARDENED" "$p2_act"
done

echo -e "---------------------------------------------------------------------------------------------------------\n"