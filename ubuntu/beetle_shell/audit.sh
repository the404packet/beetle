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

GREEN="\e[32m"
RED="\e[31m"
CYAN="\e[36m"
YELLOW="\e[33m"
RESET="\e[0m"

PASS_COUNT=0
FAIL_COUNT=0
HARDENED_COUNT=0
NOT_HARDENED_COUNT=0
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

run_check() {
    local script="$1"

    NAME=$(awk -F= '/^NAME=/{gsub(/"/,"",$2); print $2}' "$script")
    [ -z "$NAME" ] && NAME="$(basename "$script")"

    if ! is_check_enabled "$script"; then
        ((SKIPPED_COUNT++))
        return
    fi

    local module_json json_type json_file
    module_json=$(find_module_json "$script")

    if [ -n "$module_json" ]; then
        json_type="${module_json%%::*}"
        json_file="${module_json##*::}"

        load_module_json "$json_type" "$json_file" || {
            printf "${RED}[FAIL]${RESET} %s  ${RED}JSON LOAD ERROR${RESET}\n" "$NAME"
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
    bash "$script" > "$TMP_FILE" 2>/dev/null &
    pid=$!
    spinner "$pid"
    wait "$pid"
    exit_code=$?
    result=$(tr -d '\n' < "$TMP_FILE")
    rm -f "$TMP_FILE"

    # ── Unload this script's JSON from RAM ──
    [ -n "$module_json" ] && unload_module_json "$json_type"

    total_width=90
    name_length=${#NAME}
    dots_count=$(( total_width - name_length ))
    (( dots_count < 1 )) && dots_count=1
    dots=$(printf "%0.s." $(seq 1 $dots_count))

    if [ "$exit_code" -ne 0 ]; then
        printf "${RED}[FAIL]${RESET} %s %s  ${RED}ERROR${RESET}\n" "$NAME" "$dots"
        ((FAIL_COUNT++))
        return
    fi

    ((PASS_COUNT++))

    if [[ "$result" == *"HARDENED"* && "$result" != *"NOT HARDENED"* ]]; then
        ((HARDENED_COUNT++))
        STATE_COLOR="${GREEN}"
    else
        ((NOT_HARDENED_COUNT++))
        STATE_COLOR="${RED}"
    fi

    printf "${GREEN}[PASS]${RESET} %s %s  ${STATE_COLOR}%s${RESET}\n" "$NAME" "$dots" "$result"
}

echo -e "${CYAN}Starting Beetle Audit...${RESET}\n"

if [ ! -d "$BEETLE_SHELL_ROOT" ]; then
    echo -e "${RED}beetle_shell directory not found: $BEETLE_SHELL_ROOT${RESET}"
    unload_all
    exit 1
fi

TARGET_FOLDER=""
TARGET_LEVEL=""

for arg in "$@"; do
    if [ -d "$BEETLE_SHELL_ROOT/audit/$arg" ]; then
        TARGET_FOLDER="$arg"
    elif [[ "$arg" == "basic" || "$arg" == "moderate" || "$arg" == "strict" ]]; then
        TARGET_LEVEL="$arg"
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
load_severity "$TARGET_LEVEL" || { echo -e "${RED}Failed to load severity configuration${RESET}"; unload_all; exit 1; }

if [ -n "$TARGET_FOLDER" ]; then
    SEARCH_PATH="$BEETLE_SHELL_ROOT/audit/$TARGET_FOLDER"
else
    SEARCH_PATH="$BEETLE_SHELL_ROOT/audit"
fi

mapfile -d '' scripts < <(
    find "$SEARCH_PATH" \
        -mindepth 1 \
        -type f \
        -name "*.sh" \
        -print0
)

for script in "${scripts[@]}"; do
    run_check "$script"
done

# ── Unload everything from RAM ──
echo -e "\n${CYAN}Cleaning up RAM...${RESET}"
unload_all

echo
echo -e "Audit Summary : "
echo -e "+----------------------+------------------+------------+---------------+-----------+"
echo -e "| $(printf "%-20s" "Executed Successfully")| $(printf "%-16s" "Execution Failed") | $(printf "%-10s" "Hardened") | $(printf "%-13s" "Not Hardened") | $(printf "%-9s" "Skipped") |"
echo -e "+----------------------+------------------+------------+---------------+-----------+"
echo -e "| $(printf "%-20s" "$PASS_COUNT") | $(printf "%-16s" "$FAIL_COUNT") | $(printf "%-10s" "$HARDENED_COUNT") | $(printf "%-13s" "$NOT_HARDENED_COUNT") | $(printf "%-9s" "$SKIPPED_COUNT") |"
echo -e "+----------------------+------------------+------------+---------------+-----------+"