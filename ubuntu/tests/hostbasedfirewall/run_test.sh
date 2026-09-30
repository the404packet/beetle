#!/usr/bin/env bash
# =============================================================================
# ubuntu/tests/hostbasedfirewall/run_test.sh
# Automated Test Runner for hostbasedfirewall module
# =============================================================================

set -uo pipefail

GREEN="\e[32m"
RED="\e[31m"
CYAN="\e[36m"
YELLOW="\e[33m"
BOLD="\e[1m"
RESET="\e[0m"

# -----------------------------------------------------------------------------
# ROOT CHECK
# -----------------------------------------------------------------------------
if [[ "$EUID" -ne 0 ]]; then
    echo -e "${RED}[!] run_test.sh must be run as root${RESET}"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULE_NAME="hostbasedfirewall"
TARGET_MODULE="host_based_firewall"

# -----------------------------------------------------------------------------
# TRAP CLEANUP ON EXIT (GUARANTEES RESTORE)
# -----------------------------------------------------------------------------
cleanup() {
    local exit_code=$?
    trap - EXIT INT TERM
    echo ""
    echo -e "${CYAN}[*] Test finished or interrupted. Triggering automated restore...${RESET}"
    if [[ -f "$SCRIPT_DIR/restore.sh" ]]; then
        bash "$SCRIPT_DIR/restore.sh" || true
    fi
    exit "$exit_code"
}
trap cleanup EXIT INT TERM

# -----------------------------------------------------------------------------
# BEETLE ENVIRONMENT SETUP
# -----------------------------------------------------------------------------
# Locate BEETLE_SHELL_ROOT
BEETLE_SHELL_ROOT="${SCRIPT_DIR}/../../beetle_shell"
if [[ ! -d "$BEETLE_SHELL_ROOT" ]]; then
    BEETLE_SHELL_ROOT="/usr/local/bin/beetle_shell"
fi
export BEETLE_SHELL_ROOT

if [[ ! -d "$BEETLE_SHELL_ROOT" ]]; then
    echo -e "${RED}[!] beetle_shell directory not found: $BEETLE_SHELL_ROOT${RESET}"
    exit 1
fi

LIB_DIR="$BEETLE_SHELL_ROOT/lib"
source "$LIB_DIR/ram_store.sh"  || { echo -e "${RED}[!] Failed to load ram_store.sh${RESET}"; exit 1; }
source "$LIB_DIR/find_json.sh"  || { echo -e "${RED}[!] Failed to load find_json.sh${RESET}"; exit 1; }

# Locate config directory
CONFIG_DIR="${SCRIPT_DIR}/../../config"
if [[ ! -d "$CONFIG_DIR" ]]; then
    CONFIG_DIR="/etc/beetle"
fi
export SEVERITY_CONFIG_DIR="$CONFIG_DIR"

# Ensure FW_RAM_STORE is populated from firewall.json
FW_JSON="$CONFIG_DIR/firewall.json"
[[ ! -f "$FW_JSON" && -f "/etc/beetle/firewall.json" ]] && FW_JSON="/etc/beetle/firewall.json"
[[ ! -f "$FW_JSON" && -f "$CONFIG_DIR/host_based_firewall.json" ]] && FW_JSON="$CONFIG_DIR/host_based_firewall.json"

export FW_RAM_STORE="/dev/shm/beetle_fw_store.env"
python3 - <<EOF > "$FW_RAM_STORE"
import json, sys, os

fw_file = "$FW_JSON"
if os.path.exists(fw_file):
    with open(fw_file) as f:
        data = json.load(f)

    def q(v):
        return "'" + str(v).replace("'", "'\\''") + "'"

    fw = data.get('firewall', {})
    print('FW_active_tool=' + q(fw.get('active_tool', 'ufw')))

    ufw = data.get('ufw', {})
    req_pkgs = ufw.get('required_packages', [])
    print('UFW_pkg_count=' + q(len(req_pkgs)))
    for i, p in enumerate(req_pkgs):
        print(f'UFW_pkg_{i}_name=' + q(p.get('name', '')))

    banned_ufw = ufw.get('banned_with_ufw', [])
    print('UFW_banned_count=' + q(len(banned_ufw)))
    for i, p in enumerate(banned_ufw):
        print(f'UFW_banned_{i}_name=' + q(p.get('name', '')))

    lb_u = ufw.get('loopback', {})
    print('UFW_lb_allow_in=' + q(lb_u.get('allow_in', 'lo')))
    print('UFW_lb_allow_out=' + q(lb_u.get('allow_out', 'lo')))
    print('UFW_lb_deny_in=' + q(lb_u.get('deny_in', '127.0.0.0/8')))
    print('UFW_lb_deny_in6=' + q(lb_u.get('deny_in6', '::1')))

    dp_u = ufw.get('default_policies', {})
    print('UFW_policy_incoming=' + q(dp_u.get('incoming', 'deny')))
    print('UFW_policy_outgoing=' + q(dp_u.get('outgoing', 'allow')))
    print('UFW_policy_routed=' + q(dp_u.get('routed', 'disabled')))

    nft = data.get('nftables', {})
    nft_pkgs = nft.get('required_packages', [])
    print('NFT_pkg_count=' + q(len(nft_pkgs)))
    for i, p in enumerate(nft_pkgs):
        print(f'NFT_pkg_{i}_name=' + q(p.get('name', '')))

    banned_nft = nft.get('banned_with_nftables', [])
    print('NFT_banned_count=' + q(len(banned_nft)))
    for i, p in enumerate(banned_nft):
        print(f'NFT_banned_{i}_name=' + q(p.get('name', '')))

    tbl = nft.get('table', {})
    print('NFT_table_name=' + q(tbl.get('name', 'filter')))
    print('NFT_table_family=' + q(tbl.get('family', 'inet')))

    chains = nft.get('base_chains', [])
    print('NFT_chain_count=' + q(len(chains)))
    for i, c in enumerate(chains):
        print(f'NFT_chain_{i}_name=' + q(c.get('name', '')))
        print(f'NFT_chain_{i}_hook=' + q(c.get('hook', '')))
        print(f'NFT_chain_{i}_policy=' + q(c.get('policy', '')))

    lb_n = nft.get('loopback', {})
    print('NFT_lb_iface=' + q(lb_n.get('iface', 'lo')))
    print('NFT_lb_deny_in=' + q(lb_n.get('deny_in', '127.0.0.0/8')))
    print('NFT_lb_deny_in6=' + q(lb_n.get('deny_in6', '::1')))
    print('NFT_rules_file=' + q(nft.get('rules_file', '/etc/nftables.conf')))

    ipt = data.get('iptables', {})
    ipt_pkgs = ipt.get('required_packages', [])
    print('IPT_pkg_count=' + q(len(ipt_pkgs)))
    for i, p in enumerate(ipt_pkgs):
        print(f'IPT_pkg_{i}_name=' + q(p.get('name', '')))

    banned_ipt = ipt.get('banned_with_iptables', [])
    print('IPT_banned_count=' + q(len(banned_ipt)))
    for i, p in enumerate(banned_ipt):
        print(f'IPT_banned_{i}_name=' + q(p.get('name', '')))

    lb_i = ipt.get('loopback', {})
    print('IPT_lb_iface=' + q(lb_i.get('iface', 'lo')))
    print('IPT_lb_deny_in=' + q(lb_i.get('deny_in', '127.0.0.0/8')))
    print('IPT_lb_deny_in6=' + q(lb_i.get('deny_in6', '::1')))

    dp_i = ipt.get('default_policies', {})
    print('IPT_policy_input=' + q(dp_i.get('input', 'DROP')))
    print('IPT_policy_forward=' + q(dp_i.get('forward', 'DROP')))
    print('IPT_policy_output=' + q(dp_i.get('output', 'ACCEPT')))

    states = ipt.get('established_states', ['ESTABLISHED', 'RELATED'])
    print('IPT_states=' + q(','.join(states)))
    print('IPT_rules_file=' + q(ipt.get('rules_file', '/etc/iptables/rules.v4')))
    print('IPT_rules_file_v6=' + q(ipt.get('rules_file_v6', '/etc/iptables/rules.v6')))
EOF
chmod 600 "$FW_RAM_STORE"
source "$FW_RAM_STORE"

# Load packages cache into DPKG_RAM_STORE
echo -e "${CYAN}[*] Loading DPKG cache...${RESET}"
load_dpkg || { echo -e "${RED}[!] Failed to load dpkg cache${RESET}"; exit 1; }

# Always run on strict mode for both audit and hardening
echo -e "${CYAN}[*] Loading severity configuration (STRICT mode)...${RESET}"
load_severity "strict" || { echo -e "${RED}[!] Failed to load strict severity${RESET}"; exit 1; }

# Helper: Detect interactive scripts reading from /dev/tty
is_interactive_script() {
    local script="$1"
    if grep -q -E '/dev/tty|read[[:space:]]+.*</dev/tty' "$script" 2>/dev/null; then
        return 0
    fi
    return 1
}

# -----------------------------------------------------------------------------
# STEP 1: RUN UNSECURE
# -----------------------------------------------------------------------------
echo ""
echo -e "${YELLOW}====================================================================================================${RESET}"
echo -e "${YELLOW} STEP 1: RUNNING UNSECURE & CAPTURING SNAPSHOT                                                      ${RESET}"
echo -e "${YELLOW}====================================================================================================${RESET}"
bash "$SCRIPT_DIR/unsecure.sh"

# Refresh dpkg cache after unsecuring
load_dpkg

# -----------------------------------------------------------------------------
# STEP 2: INITIAL AUDIT (Expected: NOT HARDENED)
# -----------------------------------------------------------------------------
echo ""
echo -e "${CYAN}====================================================================================================${RESET}"
echo -e "${CYAN} STEP 2: INITIAL AUDIT PHASE (Expected: NOT HARDENED)                                               ${RESET}"
echo -e "${CYAN}====================================================================================================${RESET}"
printf " %-55s | %-14s | %-14s | %-6s\n" "Script Name" "Expected" "Actual" "Status"
printf -- "--------------------------------------------------------+----------------+----------------+--------\n"

SEARCH_AUDIT_PATH="$BEETLE_SHELL_ROOT/audit/$TARGET_MODULE"
mapfile -d '' AUDIT_SCRIPTS < <(
    find "$SEARCH_AUDIT_PATH" \
        -mindepth 1 \
        -type f \
        -name "*.sh" \
        -print0 | sort -z
)

INIT_AUDIT_TOTAL=0
INIT_AUDIT_PASS=0
INIT_AUDIT_FAIL=0
INIT_AUDIT_SKIPPED=0

for script in "${AUDIT_SCRIPTS[@]}"; do
    NAME=$(awk -F= '/^NAME=/{gsub(/"/,"",$2); print $2}' "$script")
    [[ -z "$NAME" ]] && NAME="$(basename "$script")"

    if ! is_check_enabled "$script"; then
        ((INIT_AUDIT_SKIPPED++))
        continue
    fi

    ((INIT_AUDIT_TOTAL++))
    expected="NOT HARDENED"

    tmp_out=$(mktemp)
    bash "$script" > "$tmp_out" 2>/dev/null || true
    raw_result=$(tr -d '\n\r' < "$tmp_out")
    rm -f "$tmp_out"

    # Normalize result text
    if [[ "$raw_result" == *"NOT HARDENED"* ]]; then
        actual="NOT HARDENED"
        status="PASS"
        status_color="${GREEN}"
        actual_color="${RED}"
        ((INIT_AUDIT_PASS++))
    elif [[ "$raw_result" == *"HARDENED"* ]]; then
        actual="HARDENED"
        status="FAIL"
        status_color="${RED}"
        actual_color="${GREEN}"
        ((INIT_AUDIT_FAIL++))
    else
        actual="${raw_result:-ERROR}"
        status="FAIL"
        status_color="${RED}"
        actual_color="${RED}"
        ((INIT_AUDIT_FAIL++))
    fi

    printf " %-55s | %-14s | ${actual_color}%-14s${RESET} | ${status_color}%-6s${RESET}\n" \
        "$NAME" "$expected" "$actual" "$status"
done

# -----------------------------------------------------------------------------
# STEP 3: APPLY HARDENING
# -----------------------------------------------------------------------------
echo ""
echo -e "${CYAN}====================================================================================================${RESET}"
echo -e "${CYAN} STEP 3: APPLYING HARDENING                                                                         ${RESET}"
echo -e "${CYAN}====================================================================================================${RESET}"
printf " %-55s | %-14s | %-14s\n" "Script Name" "Action" "Result"
printf -- "--------------------------------------------------------+----------------+----------------\n"

SEARCH_HARDEN_PATH="$BEETLE_SHELL_ROOT/harden/$TARGET_MODULE"
mapfile -d '' HARDEN_SCRIPTS < <(
    find "$SEARCH_HARDEN_PATH" \
        -mindepth 1 \
        -type f \
        -name "*.sh" \
        -print0 | sort -z
)

HARDEN_TOTAL=0
HARDEN_SUCCESS=0
HARDEN_FAILED=0
HARDEN_SKIPPED=0

for script in "${HARDEN_SCRIPTS[@]}"; do
    NAME=$(awk -F= '/^NAME=/{gsub(/"/,"",$2); print $2}' "$script")
    [[ -z "$NAME" ]] && NAME="$(basename "$script")"

    if ! is_check_enabled "$script"; then
        ((HARDEN_SKIPPED++))
        continue
    fi

    ((HARDEN_TOTAL++))

    # Detect interactive scripts reading directly from /dev/tty
    if is_interactive_script "$script"; then
        ((HARDEN_SKIPPED++))
        printf " %-55s | %-14s | ${YELLOW}%-14s${RESET}\n" "$NAME" "SKIPPED" "INTERACTIVE"
        continue
    fi

    tmp_out=$(mktemp)
    bash "$script" > "$tmp_out" 2>/dev/null || true
    raw_result=$(tr -d '\n\r' < "$tmp_out")
    rm -f "$tmp_out"

    if [[ "$raw_result" == *"SUCCESS"* ]]; then
        result="SUCCESS"
        result_color="${GREEN}"
        ((HARDEN_SUCCESS++))
    else
        result="${raw_result:-FAILED}"
        result_color="${RED}"
        ((HARDEN_FAILED++))
    fi

    printf " %-55s | %-14s | ${result_color}%-14s${RESET}\n" "$NAME" "APPLY" "$result"
done

# Refresh dpkg cache after hardening
load_dpkg

# -----------------------------------------------------------------------------
# STEP 4: FINAL AUDIT (Expected: HARDENED)
# -----------------------------------------------------------------------------
echo ""
echo -e "${CYAN}====================================================================================================${RESET}"
echo -e "${CYAN} STEP 4: FINAL AUDIT PHASE (Expected: HARDENED)                                                     ${RESET}"
echo -e "${CYAN}====================================================================================================${RESET}"
printf " %-55s | %-14s | %-14s | %-6s\n" "Script Name" "Expected" "Actual" "Status"
printf -- "--------------------------------------------------------+----------------+----------------+--------\n"

FINAL_AUDIT_TOTAL=0
FINAL_AUDIT_PASS=0
FINAL_AUDIT_FAIL=0
FINAL_AUDIT_SKIPPED=0

for script in "${AUDIT_SCRIPTS[@]}"; do
    NAME=$(awk -F= '/^NAME=/{gsub(/"/,"",$2); print $2}' "$script")
    [[ -z "$NAME" ]] && NAME="$(basename "$script")"

    if ! is_check_enabled "$script"; then
        ((FINAL_AUDIT_SKIPPED++))
        continue
    fi

    ((FINAL_AUDIT_TOTAL++))
    expected="HARDENED"

    tmp_out=$(mktemp)
    bash "$script" > "$tmp_out" 2>/dev/null || true
    raw_result=$(tr -d '\n\r' < "$tmp_out")
    rm -f "$tmp_out"

    if [[ "$raw_result" == *"HARDENED"* && "$raw_result" != *"NOT HARDENED"* ]]; then
        actual="HARDENED"
        status="PASS"
        status_color="${GREEN}"
        actual_color="${GREEN}"
        ((FINAL_AUDIT_PASS++))
    elif [[ "$raw_result" == *"NOT HARDENED"* ]]; then
        actual="NOT HARDENED"
        status="FAIL"
        status_color="${RED}"
        actual_color="${RED}"
        ((FINAL_AUDIT_FAIL++))
    else
        actual="${raw_result:-ERROR}"
        status="FAIL"
        status_color="${RED}"
        actual_color="${RED}"
        ((FINAL_AUDIT_FAIL++))
    fi

    printf " %-55s | %-14s | ${actual_color}%-14s${RESET} | ${status_color}%-6s${RESET}\n" \
        "$NAME" "$expected" "$actual" "$status"
done

# -----------------------------------------------------------------------------
# STEP 5: SUMMARY RESULTS TABLE
# -----------------------------------------------------------------------------
echo ""
echo -e "${BOLD}====================================================================================================${RESET}"
echo -e "${BOLD} TEST RUNNER SUMMARY: $MODULE_NAME                                                                  ${RESET}"
echo -e "${BOLD}====================================================================================================${RESET}"
printf " %-30s | %-10s | %-10s | %-10s | %-10s\n" "Phase" "Total" "Passed" "Failed" "Skipped"
printf -- "-------------------------------+------------+------------+------------+------------\n"
printf " %-30s | %-10d | %-10d | %-10d | %-10d\n" "Initial Audit" "$INIT_AUDIT_TOTAL" "$INIT_AUDIT_PASS" "$INIT_AUDIT_FAIL" "$INIT_AUDIT_SKIPPED"
printf " %-30s | %-10d | %-10d | %-10d | %-10d\n" "Hardening Execution" "$HARDEN_TOTAL" "$HARDEN_SUCCESS" "$HARDEN_FAILED" "$HARDEN_SKIPPED"
printf " %-30s | %-10d | %-10d | %-10d | %-10d\n" "Final Audit" "$FINAL_AUDIT_TOTAL" "$FINAL_AUDIT_PASS" "$FINAL_AUDIT_FAIL" "$FINAL_AUDIT_SKIPPED"
printf -- "-------------------------------+------------+------------+------------+------------\n"

OVERALL_PASS=true
[[ "$INIT_AUDIT_FAIL" -gt 0 || "$FINAL_AUDIT_FAIL" -gt 0 ]] && OVERALL_PASS=false

if [[ "$OVERALL_PASS" == true ]]; then
    echo -e " OVERALL MODULE TEST STATUS: ${GREEN}${BOLD}PASS${RESET}"
else
    echo -e " OVERALL MODULE TEST STATUS: ${RED}${BOLD}FAIL${RESET}"
fi
echo -e "${BOLD}====================================================================================================${RESET}"

exit 0
