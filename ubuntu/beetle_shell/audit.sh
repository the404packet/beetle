#!/usr/bin/env bash

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET_DIR="$1"

GREEN="\e[32m"
RED="\e[31m"
CYAN="\e[36m"
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

    NAME=$(awk -F= '/^NAME=/{gsub(/"/,"",$2); print $2}' "$script")

    TMP_FILE=$(mktemp)

    bash "$script" > "$TMP_FILE" 2>/dev/null &
    pid=$!
    spinner "$pid"
    wait "$pid"
    exit_code=$?

    result=$(cat "$TMP_FILE")
    rm -f "$TMP_FILE"

    # Dot padding for clean alignment (CALCULATE EARLY)
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

# Determine directories
if [ -n "$TARGET_DIR" ]; then
    SCAN_DIR="$BASE_DIR/$TARGET_DIR"
    [ -d "$SCAN_DIR" ] || { echo -e "${RED}Folder not found: $TARGET_DIR${RESET}"; exit 1; }
    DIRS=("$SCAN_DIR")
else
    DIRS=("$BASE_DIR"/*/)
fi

for dir in "${DIRS[@]}"; do
    [ -d "$dir" ] || continue
    for script in "$dir"/*.sh; do
        [ -f "$script" ] && run_check "$script"
    done
done

echo
echo -e "${GREEN}Executed Successfully: $PASS_COUNT${RESET}"
echo -e "${RED}Execution Failed: $FAIL_COUNT${RESET}"
echo -e "${GREEN}Hardened: $HARDENED_COUNT${RESET}"
echo -e "${RED}Not Hardened: $NOT_HARDENED_COUNT${RESET}"
