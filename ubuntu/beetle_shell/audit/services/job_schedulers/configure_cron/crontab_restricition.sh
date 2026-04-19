#!/usr/bin/env bash

NAME="ensure crontab is restricted to authorized users"

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

[ -f "$DPKG_RAM_STORE" ] && source "$DPKG_RAM_STORE"
[ -f "$SERVICES_RAM_STORE" ] && source "$SERVICES_RAM_STORE"

if ! is_package_installed "cron"; then
    echo -e "${GREEN}HARDENED${RESET}"
    exit 0
fi

allow_file="$JS_cron_access_allow_file"
deny_file="$JS_cron_access_deny_file"
req_mode="$JS_cron_access_mode"
req_owner="$JS_cron_access_owner"
group_count="$JS_cron_access_group_count"

check_file() {
    local file="$1"
    local actual_mode actual_owner actual_group
    actual_mode=$(stat -Lc '%a' "$file" 2>/dev/null)
    actual_owner=$(stat -Lc '%U' "$file" 2>/dev/null)
    actual_group=$(stat -Lc '%G' "$file" 2>/dev/null)

    [ "$actual_owner" != "$req_owner" ] && return 1

    local group_ok=false
    for ((i=0; i<group_count; i++)); do
        local var="JS_cron_access_group_${i}"
        local allowed_group="${!var}"
        [ "$actual_group" == "$allowed_group" ] && group_ok=true && break
    done
    $group_ok || return 1

    [ "$actual_mode" -le "$req_mode" ] 2>/dev/null || return 1
    return 0
}

if [ ! -f "$allow_file" ]; then
    echo -e "${RED}NOT HARDENED${RESET}"
    exit 0
fi

if ! check_file "$allow_file"; then
    echo -e "${RED}NOT HARDENED${RESET}"
    exit 0
fi

if [ -f "$deny_file" ]; then
    if ! check_file "$deny_file"; then
        echo -e "${RED}NOT HARDENED${RESET}"
        exit 0
    fi
fi

echo -e "${GREEN}HARDENED${RESET}"
exit 0