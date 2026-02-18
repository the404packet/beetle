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

TARGET_FOLDER="$1"

if [ -n "$TARGET_FOLDER" ]; then
    TARGET_PATH="$BEETLE_SHELL_ROOT/$TARGET_FOLDER"

    if [ ! -d "$TARGET_PATH" ]; then
        echo -e "${RED}Folder '$TARGET_FOLDER' not found inside beetle_shell${RESET}"
        exit 1
    fi

    SEARCH_PATH="$TARGET_PATH"
else
    SEARCH_PATH="$BEETLE_SHELL_ROOT"
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

echo
echo -e "${GREEN}Executed Successfully: $PASS_COUNT${RESET}"
echo -e "${RED}Execution Failed: $FAIL_COUNT${RESET}"
echo -e "${GREEN}Hardened: $HARDENED_COUNT${RESET}"
echo -e "${RED}Not Hardened: $NOT_HARDENED_COUNT${RESET}"
