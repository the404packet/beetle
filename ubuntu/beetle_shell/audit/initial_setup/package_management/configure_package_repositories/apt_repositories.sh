#!/usr/bin/env bash

NAME="ensure package manager repositories are configured"

GREEN="\e[32m"
RED="\e[31m"
CYAN="\e[36m"
RESET="\e[0m"

[ -f "$INITIAL_SETUP_RAM_STORE" ] && source "$INITIAL_SETUP_RAM_STORE"

repo_count="$PM_repo_count"
codename=$(lsb_release -sc 2>/dev/null)
failed=false

for ((i=0; i<repo_count; i++)); do
    repo_var="PM_repo_${i}"
    repo="${!repo_var}"
    repo="${repo/\{codename\}/$codename}"

    if ! grep -Pq "^\s*${repo}\s*$" "$PM_sources_file" 2>/dev/null; then
        failed=true
        break
    fi
done

$failed && echo -e "${RED}NOT HARDENED${RESET}" || echo -e "${GREEN}HARDENED${RESET}"
exit 0