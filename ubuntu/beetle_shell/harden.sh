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
SUCCESS_COUNT=0
FAILED_COUNT=0

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

    SEVERITY=$(grep -E '^SEVERITY=' "$script" | cut -d= -f2 | tr -d '"[:space:]')

    if [ -n "$TARGET_SEVERITY" ]; then
        if [[ "${SEVERITY,,}" != "${TARGET_SEVERITY,,}" ]]; then
            return
        fi
    fi

    NAME=$(awk -F= '/^NAME=/{gsub(/"/,"",$2); print $2}' "$script")
    [ -z "$NAME" ] && NAME="$(basename "$script")"

    local json_file
    json_file=$(find_module_json "$script")

    if [ -n "$json_file" ]; then
        load_json_permissions "$json_file" || {
            printf "${RED}[FAIL]${RESET} %s  ${RED}JSON LOAD ERROR${RESET}\n" "$NAME"
            ((FAIL_COUNT++))
            return
        }
    fi

    export DPKG_RAM_STORE
    export PERM_RAM_STORE

    TMP_FILE=$(mktemp)
    bash "$script" > "$TMP_FILE" 2>/dev/null &
    pid=$!
    spinner "$pid"
    wait "$pid"
    exit_code=$?
    result=$(tr -d '\n' < "$TMP_FILE")
    rm -f "$TMP_FILE"

    # Unload this script's JSON from RAM
    [ -n "$json_file" ] && unload_json_permissions

    total_width=75
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

    if [[ "$result" == *"SUCCESS"* ]]; then
        ((SUCCESS_COUNT++))
        STATE_COLOR="${GREEN}"
    else
        ((FAILED_COUNT++))
        STATE_COLOR="${RED}"
    fi

    printf "${GREEN}[DONE]${RESET} %s %s  ${STATE_COLOR}%s${RESET}\n" "$NAME" "$dots" "$result"
}

echo -e "${CYAN}Starting Beetle Hardening...${RESET}\n"

if [ ! -d "$BEETLE_SHELL_ROOT" ]; then
    echo -e "${RED}beetle_shell directory not found: $BEETLE_SHELL_ROOT${RESET}"
    unload_all
    exit 1
fi

echo -e "${CYAN}Loading package database into RAM...${RESET}\n"
load_dpkg || { echo -e "${RED}Failed to load dpkg into RAM${RESET}"; unload_all; exit 1; }

TARGET_FOLDER=""
TARGET_SEVERITY=""

for arg in "$@"; do
    if [ -d "$BEETLE_SHELL_ROOT/harden/$arg" ]; then
        TARGET_FOLDER="$arg"
    else
        TARGET_SEVERITY="$arg"
    fi
done

if [ -n "$TARGET_FOLDER" ]; then
    SEARCH_PATH="$BEETLE_SHELL_ROOT/harden/$TARGET_FOLDER"
else
    SEARCH_PATH="$BEETLE_SHELL_ROOT/harden"
fi

mapfile -d '' scripts < <(
    find "$SEARCH_PATH" \
        -mindepth 1 \
        -type f \
        -name "*.sh" \
        -print0
)

for script in "${scripts[@]}"; do
    run_harden "$script"
done

echo -e "\n${CYAN}Cleaning up RAM...${RESET}"
unload_all

echo
echo -e "Harden Summary : "
echo -e "+----------------------+------------------+------------+---------------+"
echo -e "| $(printf "%-20s" "Executed Successfully")| $(printf "%-16s" "Execution Failed") | $(printf "%-10s" "Succeeded") | $(printf "%-13s" "Failed") |"
echo -e "+----------------------+------------------+------------+---------------+"
echo -e "| $(printf "%-20s" "$PASS_COUNT") | $(printf "%-16s" "$FAIL_COUNT") | $(printf "%-10s" "$SUCCESS_COUNT") | $(printf "%-13s" "$FAILED_COUNT") |"
echo -e "+----------------------+------------------+------------+---------------+"