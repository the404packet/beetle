#!/usr/bin/env bash
# =============================================================================
# run_test.sh - Automated test runner for Beetle services module
#
# Workflow:
# 1. Create custom backup snapshot & unsecure all services settings
# 2. Run Beetle Audit Phase 1 (Expected: NOT HARDENED, Actual: verified)
# 3. Run Beetle Harden Phase (Skip interactive scripts reading /dev/tty)
# 4. Run Beetle Audit Phase 2 (Expected: HARDENED, Actual: verified)
# 5. Output real-time progress and summary comparison results table
# 6. Restore original system state from backup (via trap cleanup EXIT)
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BEETLE_SHELL_ROOT="$(cd "$SCRIPT_DIR/../../beetle_shell" && pwd)"
CONFIG_DIR="$(cd "$SCRIPT_DIR/../../config" && pwd)"
SERVICES_JSON="$CONFIG_DIR/services.json"

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
BOLD="\e[1m"
RESET="\e[0m"

# Root check
if [[ "$EUID" -ne 0 ]]; then
    echo -e "${RED}[!] run_test.sh must be run as root${RESET}"
    exit 1
fi

cleanup() {
    echo -e "\n${CYAN}=== Restoring original system state ===${RESET}"
    bash "$RESTORE_SCRIPT" || true
    unload_all || true
}
trap cleanup EXIT

# -----------------------------------------------------------------------------
# Setup test shims in /tmp/beetle_services_bin
# 1. apt-get: intercepts package remove/purge and unsets flags in DPKG_RAM_STORE
#    without touching real host packages or prompting on /dev/tty.
# 2. systemctl: intercepts stop/disable/mask for display-manager (GDM/LightDM/SDDM)
#    so the GUI desktop session is NOT killed during xwindow hardening.
# -----------------------------------------------------------------------------
SHIM_DIR="/tmp/beetle_services_bin"
mkdir -p "$SHIM_DIR"

cat << 'EOF' > "$SHIM_DIR/apt-get"
#!/usr/bin/env bash
DPKG_ENV="/dev/shm/beetle_dpkg.env"
if [[ "$1" == "remove" || "$1" == "purge" || "$1" == "autoremove" ]]; then
    for arg in "$@"; do
        if [[ "$arg" != -* && "$arg" != "remove" && "$arg" != "purge" && "$arg" != "autoremove" ]]; then
            safe_pkg=$(echo "$arg" | sed 's/[^a-zA-Z0-9_]/_/g')
            if [[ -f "$DPKG_ENV" ]]; then
                sed -i "/^PKG_${safe_pkg}=/d" "$DPKG_ENV" 2>/dev/null || true
                sed -i "/^PKG_${safe_pkg}_/d" "$DPKG_ENV" 2>/dev/null || true
            fi
        fi
    done
fi
exit 0
EOF
chmod +x "$SHIM_DIR/apt-get"

cat << 'EOF' > "$SHIM_DIR/systemctl"
#!/usr/bin/env bash
REAL_SYSTEMCTL="/bin/systemctl"
[[ -x "/usr/bin/systemctl" ]] && REAL_SYSTEMCTL="/usr/bin/systemctl"

# Protect critical GUI display managers from being stopped or disabled
if [[ "$1" == "stop" || "$1" == "disable" || "$1" == "mask" ]]; then
    for arg in "$@"; do
        case "$arg" in
            *display-manager*|*gdm*|*lightdm*|*sddm*|*x11*|*wayland*)
                exit 0
                ;;
        esac
    done
fi

exec "$REAL_SYSTEMCTL" "$@"
EOF
chmod +x "$SHIM_DIR/systemctl"

export PATH="$SHIM_DIR:$PATH"

echo -e "${CYAN}========================================================================================${RESET}"
echo -e "${CYAN}                     Beetle Services Module Test Suite Runner                           ${RESET}"
echo -e "${CYAN}========================================================================================${RESET}\n"

# -----------------------------------------------------------------------------
# STEP 1: UNSECURE SETTINGS
# -----------------------------------------------------------------------------
echo -e "${YELLOW}[STEP 1] Unsecuring all services settings & capturing snapshot...${RESET}"
bash "$UNSECURE_SCRIPT"

# Load environment dependencies for running audit & harden scripts
echo -e "${CYAN}[*] Loading DPKG cache, strict severity, and services JSON into RAM store...${RESET}"
load_dpkg
load_severity "strict"
load_json_services "$SERVICES_JSON"

# Apply unsecure package overlay into DPKG_RAM_STORE so initial audit reflects unhardened state
if [[ -f "/tmp/beetle_services_backup/unsecure_pkgs.env" && -f "$DPKG_RAM_STORE" ]]; then
    cat "/tmp/beetle_services_backup/unsecure_pkgs.env" >> "$DPKG_RAM_STORE"
fi

export DPKG_RAM_STORE SERVICES_RAM_STORE SEVERITY_RAM_STORE

# Find all audit scripts under services
mapfile -d '' AUDIT_SCRIPTS < <(
    find "$BEETLE_SHELL_ROOT/audit/services" \
        -mindepth 1 -type f -name "*.sh" -print0 | sort -z
)

# Phase 1 Audit Results Data Structures
declare -A SCRIPT_NAMES
declare -A INITIAL_ACTUAL
declare -A INITIAL_STATUS

# -----------------------------------------------------------------------------
# STEP 2: RUN INITIAL AUDIT (Expected: NOT HARDENED)
# -----------------------------------------------------------------------------
echo -e "\n${YELLOW}[STEP 2] Running Initial Audit (Expected: NOT HARDENED)...${RESET}"
printf " %-55s | %-14s | %-14s | %-6s\n" "Script Name" "Expected" "Actual" "Status"
printf -- "--------------------------------------------------------+----------------+----------------+--------\n"

for script in "${AUDIT_SCRIPTS[@]}"; do
    rel_path="${script#$BEETLE_SHELL_ROOT/audit/services/}"
    script_id="${rel_path%.sh}"

    name=$(awk -F= '/^NAME=/{gsub(/"/,"",$2); print $2}' "$script")
    [[ -z "$name" ]] && name="$(basename "$script")"
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

    printf " %-55s | %-14s | ${COLOR}%-14s${RESET} | ${COLOR}%s${RESET}\n" \
        "$name" "NOT HARDENED" "$ACTUAL" "$STATUS"
done

# -----------------------------------------------------------------------------
# STEP 3: RUN BEETLE HARDEN
# -----------------------------------------------------------------------------
echo -e "\n${YELLOW}[STEP 3] Running Beetle Harden for services...${RESET}"
mapfile -d '' HARDEN_SCRIPTS < <(
    find "$BEETLE_SHELL_ROOT/harden/services" \
        -mindepth 1 -type f -name "*.sh" -print0 | sort -z
)

for script in "${HARDEN_SCRIPTS[@]}"; do
    name=$(awk -F= '/^NAME=/{gsub(/"/,"",$2); print $2}' "$script")
    [[ -z "$name" ]] && name="$(basename "$script")"

    # Detect and skip interactive harden scripts reading directly from /dev/tty
    if grep -q -E '/dev/tty|read[[:space:]]+.*</dev/tty' "$script" 2>/dev/null; then
        printf "  Harden: %-52s | Result: ${YELLOW}%s${RESET}\n" "$name" "SKIPPED (Interactive)"
        continue
    fi

    TMP_FILE=$(mktemp)
    # Feed multiple default responses for interactive read loops, with a timeout safety guard
    printf '\n%.0s' {1..50} | timeout 15 bash "$script" > "$TMP_FILE" 2>/dev/null || true
    harden_res=$(tr -d '\r' < "$TMP_FILE" | tr '\n' ' ' | xargs)
    rm -f "$TMP_FILE"

    if [[ "$harden_res" == *"SUCCESS"* ]]; then
        printf "  Harden: %-52s | Result: ${GREEN}%s${RESET}\n" "$name" "SUCCESS"
    else
        printf "  Harden: %-52s | Result: ${RED}%s${RESET}\n" "$name" "FAILED"
    fi
done

# -----------------------------------------------------------------------------
# STEP 4: RUN FINAL AUDIT (Expected: HARDENED)
# -----------------------------------------------------------------------------
echo -e "\n${YELLOW}[STEP 4] Running Final Audit after Hardening (Expected: HARDENED)...${RESET}"
printf " %-55s | %-14s | %-14s | %-6s\n" "Script Name" "Expected" "Actual" "Status"
printf -- "--------------------------------------------------------+----------------+----------------+--------\n"

declare -A FINAL_ACTUAL
declare -A FINAL_STATUS

for script in "${AUDIT_SCRIPTS[@]}"; do
    rel_path="${script#$BEETLE_SHELL_ROOT/audit/services/}"
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

    printf " %-55s | %-14s | ${COLOR}%-14s${RESET} | ${COLOR}%s${RESET}\n" \
        "$name" "HARDENED" "$ACTUAL" "$STATUS"
done

# -----------------------------------------------------------------------------
# STEP 5: PRINT SUMMARY RESULTS TABLE
# -----------------------------------------------------------------------------
echo -e "\n${CYAN}========================================================================================${RESET}"
echo -e "${CYAN}                            TEST SUMMARY RESULTS TABLE                                  ${RESET}"
echo -e "${CYAN}========================================================================================${RESET}"
printf "%-55s | %-15s | %-15s | %-8s\n" "Script Name" "Initial Audit" "Final Audit" "Result"
echo -e "----------------------------------------------------------------------------------------"

pass_count=0
fail_count=0
total_count=0

for script in "${AUDIT_SCRIPTS[@]}"; do
    rel_path="${script#$BEETLE_SHELL_ROOT/audit/services/}"
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
    printf "%-55s | %-15s | %-15s | ${res_color}%-8s${RESET}\n" "$name" "$init" "$fin" "$res_str"
done

echo -e "----------------------------------------------------------------------------------------"
echo -e "Total Checks: $total_count | ${GREEN}Passed: $pass_count${RESET} | ${RED}Failed: $fail_count${RESET}"
echo -e "${CYAN}========================================================================================${RESET}"

if [[ "$fail_count" -gt 0 ]]; then
    exit 1
fi

exit 0
