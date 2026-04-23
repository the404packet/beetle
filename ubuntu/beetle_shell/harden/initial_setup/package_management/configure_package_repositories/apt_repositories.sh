#!/usr/bin/env bash

NAME="ensure package manager repositories are configured"

GREEN="\e[32m"
RED="\e[31m"
CYAN="\e[36m"
RESET="\e[0m"

[ -f "$INITIAL_SETUP_RAM_STORE" ] && source "$INITIAL_SETUP_RAM_STORE"

echo ""
echo -e "${CYAN}  Current APT repositories:${RESET}"
apt-cache policy 2>/dev/null | grep -E 'http|file:' | head -20
echo ""
echo -e "  Beetle recommends the following repository configuration:"

repo_count="$PM_repo_count"
codename=$(lsb_release -sc 2>/dev/null)
for ((i=0; i<repo_count; i++)); do
    repo_var="PM_repo_${i}"
    repo="${!repo_var}"
    echo "    ${repo/\{codename\}/$codename}"
done

echo ""
echo -e "  Press ${GREEN}ENTER${RESET} to apply beetle recommended config"
echo -e "  Type   ${RED}no${RESET}   to keep current config"
read -r -p "  Choice: " response

if [[ "$response" == "no" ]]; then
    echo -e "${GREEN}SUCCESS${RESET}"
    exit 0
fi

sources_file="$PM_sources_file"
> "$sources_file"

for ((i=0; i<repo_count; i++)); do
    repo_var="PM_repo_${i}"
    repo="${!repo_var}"
    echo "${repo/\{codename\}/$codename}" >> "$sources_file"
done

apt-get update &>/dev/null

if apt-cache policy 2>/dev/null | grep -qE 'http|file:'; then
    echo -e "${GREEN}SUCCESS${RESET}"
else
    echo -e "${RED}FAILED${RESET}"
    exit 1
fi

exit 0