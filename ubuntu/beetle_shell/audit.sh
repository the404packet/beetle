#!/usr/bin/env bash

CONFIG_FILE="/etc/beetle/beetle.conf"
[ -f "$CONFIG_FILE" ] && source "$CONFIG_FILE"

BEETLE_SHELL_ROOT="${BEETLE_SHELL_ROOT:-/usr/local/bin/beetle_shell}"

GREEN="\e[32m"
RED="\e[31m"
CYAN="\e[36m"
YELLOW="\e[33m"
RESET="\e[0m"

PASS_COUNT=0
FAIL_COUNT=0
HARDENED_COUNT=0
NOT_HARDENED_COUNT=0

spinner() {
    local pid=$1
    local spin='-\|/'
    local i=0
    while kill -0 "$pid" 2>/dev/null; do
        i=$(( (i+1) %4 ))
        printf "\r  ${CYAN}%s${RESET}" "${spin:$i:1}"
        sleep 0.1
    done
}

run_check() {
    local script="$1"
    
    SEVERITY=$(grep -E '^SEVERITY=' "$script" | cut -d= -f2 | tr -d '"[:space:]')

    if [ -n "$TARGET_SEVERITY" ]; then
        if [[ "${SEVERITY,,}" != "${TARGET_SEVERITY,,}" ]]; then
            return
        fi
    fi


    NAME=$(awk -F= '/^NAME=/{gsub(/"/,"",$2); print $2}' "$script")
    [ -z "$NAME" ] && NAME="$(basename "$script")"

    TMP_FILE=$(mktemp)

    bash "$script" > "$TMP_FILE" 2>/dev/null &
    pid=$!
    spinner "$pid"
    wait "$pid"
    exit_code=$?

    result=$(cat "$TMP_FILE")
    rm -f "$TMP_FILE"

    total_width=75
    name_length=${#NAME}
    dots_count=$(( total_width - name_length ))
    (( dots_count < 1 )) && dots_count=1
    dots=$(printf "%0.s." $(seq 1 $dots_count))

    if [ "$exit_code" -ne 0 ]; then
        printf "\r${RED}[FAIL]${RESET} %s %s  ${RED}ERROR${RESET}\n" "$NAME" "$dots"
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

    printf "\r${GREEN}[PASS]${RESET} %s %s  ${STATE_COLOR}%s${RESET}\n" "$NAME" "$dots" "$result"
}

echo -e "${CYAN}Starting Beetle Audit...${RESET}\n"

if [ ! -d "$BEETLE_SHELL_ROOT" ]; then
    echo -e "${RED}beetle_shell directory not found${RESET}"
    exit 1
fi

TARGET_FOLDER=""
TARGET_SEVERITY=""

# Parse arguments
for arg in "$@"; do
    if [ -d "$BEETLE_SHELL_ROOT/$arg" ]; then
        TARGET_FOLDER="$arg"
    else
        TARGET_SEVERITY="$arg"
    fi
done

# Determine search path
if [ -n "$TARGET_FOLDER" ]; then
    SEARCH_PATH="$BEETLE_SHELL_ROOT/$TARGET_FOLDER"
else
    SEARCH_PATH="$BEETLE_SHELL_ROOT"
fi

# Collect scripts
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

echo
echo -e "Audit Summary : "
echo -e "+----------------------+------------------+------------+---------------+"
echo -e "| $(printf "%-20s" "Executed Successfully")| $(printf "%-16s" "Execution Failed") | $(printf "%-10s" "Hardened") | $(printf "%-13s" "Not Hardened") |"
echo -e "+----------------------+------------------+------------+---------------+"
echo -e "| $(printf "%-20s" "$PASS_COUNT") | $(printf "%-16s" "$FAIL_COUNT") | $(printf "%-10s" "$HARDENED_COUNT") | $(printf "%-13s" "$NOT_HARDENED_COUNT") |"
echo -e "+----------------------+------------------+------------+---------------+"