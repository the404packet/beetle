#!/usr/bin/env bash

CONFIG_FILE="/etc/beetle/beetle.conf"
[ -f "$CONFIG_FILE" ] && source "$CONFIG_FILE"

# Derive root from script's own location — never trust $BEETLE_SHELL_ROOT alone
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BEETLE_SHELL_ROOT="${SCRIPT_DIR}"
export BEETLE_SHELL_ROOT

LIB_DIR="$BEETLE_SHELL_ROOT/lib"
source "$LIB_DIR/ram_store.sh"  || { echo "ERROR: cannot load ram_store.sh"; exit 1; }
source "$LIB_DIR/find_json.sh"  || { echo "ERROR: cannot load find_json.sh"; exit 1; }
source "$LIB_DIR/order.sh"    || { echo "ERROR: cannot load order.sh"; exit 1; }
source "$LIB_DIR/report.sh"   || { echo "ERROR: cannot load report.sh"; exit 1; }

GREEN="\e[32m"
RED="\e[31m"
CYAN="\e[36m"
YELLOW="\e[33m"
RESET="\e[0m"

PASS_COUNT=0
FAIL_COUNT=0
SUCCESS_COUNT=0
FAILED_COUNT=0
SKIPPED_COUNT=0

spinner() {
    local pid=$1
    if [[ "$ENABLE_SPINNER" != true ]]; then return; fi
    local spin='-\|/'
    local i=0
    while kill -0 "$pid" 2>/dev/null; do
        i=$(( (i+1) %4 ))
        printf "\r  ${CYAN}%s${RESET}" "${spin:$i:1}"
        sleep 0.1
    done
    printf "\r"
}

run_harden() {
    local script="$1"
    NAME=$(awk -F= '/^NAME=/{gsub(/"/,"",$2); print $2}' "$script")
    [ -z "$NAME" ] && NAME="$(basename "$script")"

    if ! is_check_enabled "$script"; then
        ((SKIPPED_COUNT++))
        return
    fi

    # ── Find this script's JSON ──
    local module_json json_type json_file
    module_json=$(find_module_json "$script")

    if [ -n "$module_json" ]; then
        json_type="${module_json%%::*}"
        json_file="${module_json##*::}"
        load_module_json "$json_type" "$json_file" || {
            printf "${RED}[FAIL]${RESET} %s ${RED}JSON LOAD ERROR${RESET}\n" "$NAME"
            ((FAIL_COUNT++))
            return
        }
    fi

    export DPKG_RAM_STORE
    export PERM_RAM_STORE
    export SEVERITY_RAM_STORE
    export NETWORK_RAM_STORE
    export SERVICES_RAM_STORE
    export ACCESS_RAM_STORE
    export FW_RAM_STORE
    export LOGGING_RAM_STORE
    export INITIAL_SETUP_RAM_STORE

    TMP_FILE=$(mktemp)

    # ── KEY FIX: --line-buffered forces grep to pass PROMPT: immediately ──
     (
        stdbuf -oL -eL bash "$script" 2>&1 \
            | stdbuf -oL tee "$TMP_FILE" \
            | grep --line-buffered -v -P '^(\x1b\[[0-9;]*m)?(SUCCESS|FAILED)(\x1b\[[0-9;]*m)?$'
        exit "${PIPESTATUS[0]}"
    ) &
    pid=$!

    wait "$pid"
    exit_code=$?

    # Extract final execution outcome from captured output log
    result=$(grep -E 'SUCCESS|FAILED' "$TMP_FILE" | tail -n 1 || true)
    [ -z "$result" ] && result="FAILED"
    rm -f "$TMP_FILE"

    # ── Unload this script's JSON from RAM ──
    [ -n "$module_json" ] && unload_module_json "$json_type"

    total_width=75
    name_length=${#NAME}
    dots_count=$(( total_width - name_length ))
    (( dots_count < 1 )) && dots_count=1
    dots=$(printf "%0.s." $(seq 1 $dots_count))

    if [ "$exit_code" -ne 0 ]; then
        printf "${RED}[FAIL]${RESET} %s %s ${RED}ERROR${RESET}\n" "$NAME" "$dots"
        ((FAIL_COUNT++))
        return
    fi

    ((PASS_COUNT++))

    if [[ "$result" == *"SUCCESS"* ]]; then
        ((SUCCESS_COUNT++))
        STATE_COLOR="${GREEN}"
    else
        ((FAILED_COUNT++))
        STATE_COLOR="${RED}"
    fi

    if [ "$GENERATE_REPORT" = true ]; then
        local rel="${script#$BEETLE_SHELL_ROOT/harden/}"
        report_add "$rel" "$NAME" "$result"
    fi

    printf "${GREEN}[DONE]${RESET} %s %s ${STATE_COLOR}%s${RESET}\n" "$NAME" "$dots" "$result"
}
echo -e "${CYAN}Starting Beetle Hardening...${RESET}\n"

if [ ! -d "$BEETLE_SHELL_ROOT" ]; then
    echo -e "${RED}beetle_shell directory not found: $BEETLE_SHELL_ROOT${RESET}"
    unload_all
    exit 1
fi

# ── Parse arguments ──
TARGET_FOLDER=""
TARGET_LEVEL=""
GENERATE_REPORT=false

for arg in "$@"; do
    if [ -d "$BEETLE_SHELL_ROOT/harden/$arg" ]; then
        TARGET_FOLDER="$arg"
    elif [[ "$arg" == "basic" || "$arg" == "moderate" || "$arg" == "strict" ]]; then
        TARGET_LEVEL="$arg"
    elif [[ "$arg" == "--generate-report" ]]; then
        GENERATE_REPORT=true
    fi
done

if [ -z "$TARGET_LEVEL" ]; then
    TARGET_LEVEL="${DEFAULT_SEVERITY:-basic}"
fi

TARGET_LEVEL=${TARGET_LEVEL^^}

echo -e "${CYAN}Severity level : ${YELLOW}${TARGET_LEVEL}${RESET}\n"

echo -e "${CYAN}Loading packages......${RESET}"
load_dpkg || { echo -e "${RED}Failed to load dpkg${RESET}"; unload_all; exit 1; }

echo -e "${CYAN}Loading severity configuration.......${RESET}\n"
load_severity "${TARGET_LEVEL,,}" || { echo -e "${RED}Failed to load severity configuration${RESET}"; unload_all; exit 1; }

# ── Determine search path ──
if [ -n "$TARGET_FOLDER" ]; then
    SEARCH_PATH="$BEETLE_SHELL_ROOT/harden/$TARGET_FOLDER"
else
    SEARCH_PATH="$BEETLE_SHELL_ROOT/harden"
fi

mapfile -t scripts < <(ordered_scripts "$SEARCH_PATH")

echo -e "${CYAN}Capturing pre-harden snapshot...${RESET}"

if [[ "${SKIP_SNAPSHOT:-false}" == "true" ]]; then
    echo -e "${YELLOW}Skipping pre-harden snapshot (test runner mode)${RESET}\n"
else
    SNAP_RESPONSE=$(beetle snapshot capture main 2>&1)

    if echo "$SNAP_RESPONSE" | grep -q "\[+\] Snapshot created"; then
        echo -e "${GREEN}Snapshot captured${RESET}\n"
        # Extract snapshot ID for report
        SNAP_ID_REPORT=$(echo "$SNAP_RESPONSE" | awk '/ID *:/{print $NF}')
        if [ "$GENERATE_REPORT" = true ] && [ -n "$SNAP_ID_REPORT" ]; then
            # Restart report with snapshot id
            report_init "harden" "$TARGET_LEVEL" "$SNAP_ID_REPORT"
        fi
    else
        echo -e "${RED}Snapshot failed — aborting${RESET}"
        echo "$SNAP_RESPONSE"
        unload_all
        exit 1
    fi
fi

for script in "${scripts[@]}"; do
    run_harden "$script"
done

# ── Unload everything from RAM ──
echo -e "\n${CYAN}Cleaning up RAM...${RESET}"
unload_all

echo
echo -e "Harden Summary : "
echo -e "+----------------------+------------------+------------+---------------+"
echo -e "| $(printf "%-20s" "Executed Successfully")| $(printf "%-16s" "Execution Failed") | $(printf "%-10s" "Succeeded") | $(printf "%-13s" "Failed") |"
echo -e "+----------------------+------------------+------------+---------------+"
echo -e "| $(printf "%-20s" "$PASS_COUNT") | $(printf "%-16s" "$FAIL_COUNT") | $(printf "%-10s" "$SUCCESS_COUNT") | $(printf "%-13s" "$FAILED_COUNT") |"
echo -e "+----------------------+------------------+------------+---------------+"
# ── Generate PDF report ──
if [ "$GENERATE_REPORT" = true ]; then
    report_finalize
fi
