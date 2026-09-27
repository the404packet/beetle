#!/usr/bin/env bash

NAME="ensure at is restricted to authorized users"

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

[ -f "$DPKG_RAM_STORE" ] && source "$DPKG_RAM_STORE"
[ -f "$SERVICES_RAM_STORE" ] && source "$SERVICES_RAM_STORE"

if ! is_package_installed "at"; then
    echo -e "${GREEN}SUCCESS${RESET}"
    exit 0
fi

allow_file="${JS_at_access_allow_file:-}"
deny_file="${JS_at_access_deny_file:-}"
req_mode="${JS_at_access_mode:-}"
req_owner="${JS_at_access_owner:-}"
group_count="${JS_at_access_group_count:-0}"

# If JSON did not define this block, nothing to harden
if [ -z "$allow_file" ] || [ -z "$req_mode" ] || [ -z "$req_owner" ]; then
    echo -e "${GREEN}SUCCESS${RESET}"
    exit 0
fi

# pick group — first existing group from JSON list, else root
req_group="root"
for ((i=0; i<group_count; i++)); do
    var="JS_at_access_group_${i}"
    grp="${!var}"
    [ -z "$grp" ] && continue
    if grep -q -- "^${grp}:" /etc/group 2>/dev/null; then
        req_group="$grp"
        break
    fi
done

# create at.allow if missing
[ ! -f "$allow_file" ] && touch "$allow_file" 2>/dev/null || true

chown "${req_owner}:${req_group}" -- "$allow_file" 2>/dev/null || true
chmod "$req_mode"                  -- "$allow_file" 2>/dev/null || true

if [ -f "$deny_file" ]; then
    chown "${req_owner}:${req_group}" -- "$deny_file" 2>/dev/null || true
    chmod "$req_mode"                  -- "$deny_file" 2>/dev/null || true
fi

# verify
actual_mode=$(stat -Lc '%a' "$allow_file" 2>/dev/null)
actual_owner=$(stat -Lc '%U' "$allow_file" 2>/dev/null)
actual_group=$(stat -Lc '%G' "$allow_file" 2>/dev/null)

if [ "$actual_owner" != "$req_owner" ] || [ "$actual_group" != "$req_group" ] || [ "$actual_mode" -gt "$req_mode" ] 2>/dev/null; then
    echo -e "${RED}FAILED${RESET}"
    exit 1
fi

echo -e "${GREEN}SUCCESS${RESET}"
exit 0
