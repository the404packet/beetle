#!/usr/bin/env bash

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"

GREEN="\033[0;32m"
RED="\033[0;31m"
CYAN="\033[0;36m"
RESET="\033[0m"

SPINNER_CHARS='|/-\'

total=0
success=0
failed=0

spinner() {
    local pid=$1
    local delay=0.1

    while ps -p $pid > /dev/null 2>&1; do
        for i in $(seq 0 3); do
            printf "\r[%c] Running..." "${SPINNER_CHARS:$i:1}"
            sleep $delay
        done
    done
}

run_checks_in_folder() {
    local folder="$1"

    for file in "$folder"/*.sh; do
        [[ -f "$file" ]] || continue

        ((total++))

        chmod +x "$file"

        printf "${CYAN}→ %s ${RESET}" "$(basename "$file")"

        "$file" >/dev/null 2>&1 &
        pid=$!

        spinner $pid
        wait $pid
        exit_code=$?

        if [[ $exit_code -eq 0 ]]; then
            printf "\r${GREEN}✔ %s${RESET}\n" "$(basename "$file")"
            ((success++))
        else
            printf "\r${RED}✖ %s${RESET}\n" "$(basename "$file")"
            ((failed++))
        fi
    done
}

TARGET="$1"

echo -e "${CYAN}🔍 Starting Audit...${RESET}\n"

if [[ -z "$TARGET" ]]; then
    for dir in "$BASE_DIR"/*/; do
        [[ -d "$dir" ]] || continue
        echo -e "${CYAN}📂 $(basename "$dir")${RESET}"
        run_checks_in_folder "$dir"
        echo
    done
else
    FOLDER_PATH="$BASE_DIR/$TARGET"
    if [[ -d "$FOLDER_PATH" ]]; then
        echo -e "${CYAN}📂 $TARGET${RESET}"
        run_checks_in_folder "$FOLDER_PATH"
    else
        echo -e "${RED}Unknown audit folder: $TARGET${RESET}"
        exit 1
    fi
fi

echo
echo -e "${CYAN}──────────── Summary ────────────${RESET}"
echo -e "Total Checks : $total"
echo -e "${GREEN}Passed       : $success${RESET}"
echo -e "${RED}Failed       : $failed${RESET}"
echo -e "${CYAN}─────────────────────────────────${RESET}"

exit $failed
