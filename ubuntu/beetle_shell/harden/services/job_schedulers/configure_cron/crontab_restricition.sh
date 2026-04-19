#!/usr/bin/env bash

NAME="ensure crontab is restricted to authorized users"

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

[ -f "$DPKG_RAM_STORE" ] && source "$DPKG_RAM_STORE"
[ -f "$SERVICES_RAM_STORE" ] && source "$SERVICES_RAM_STORE"

if ! is_package_installed "cron"; then
    echo -e "${GREEN}SUCCESS${RESET}"
    exit 0
fi

allow_file="$JS_cron_access_allow_file"
deny_file="$JS_cron_access_deny_file"
req_mode="$JS_cron_access_mode"
req_owner="$JS_cron_access_owner"
group_count="$JS_cron_access_group_count"

# pick group — crontab if exists else root
req_group="root"
for ((i=0; i<group_count; i++)); do
    var="JS_cron_access_group_${i}"
    grp="${!var}"
    if grep -Pq -- "^${grp}:" /etc/group 2>/dev/null; then
        req_group="$grp"
        break
    fi
done

[ ! -f "$allow_file" ] && touch "$allow_file"

chown "${req_owner}:${req_group}" "$allow_file"
chmod u-x,g-wx,o-rwx "$allow_file"

if [ -f "$deny_file" ]; then
    chown "${req_owner}:${req_group}" "$deny_file"
    chmod u-x,g-wx,o-rwx "$deny_file"
fi

actual_mode=$(stat -Lc '%a' "$allow_file" 2>/dev/null)
actual_owner=$(stat -Lc '%U' "$allow_file" 2>/dev/null)
actual_group=$(stat -Lc '%G' "$allow_file" 2>/dev/null)

if [ "$actual_owner" != "$req_owner" ] || [ "$actual_group" != "$req_group" ] || [ "$actual_mode" -gt "$req_mode" ] 2>/dev/null; then
    echo -e "${RED}FAILED${RESET}"
    exit 1
fi

echo -e "${GREEN}SUCCESS${RESET}"
exit 0