#!/usr/bin/env bash

NAME="ensure sudo authentication timeout is configured correctly"
SEVERITY='basic'

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

[ -f "$SSH_RAM_STORE" ] && source "$SSH_RAM_STORE"

MAX_TIMEOUT="${SUDO_TIMESTAMP_TIMEOUT_MAX:-15}"

if ! is_package_installed "sudo" && ! is_package_installed "sudo-ldap"; then
    echo -e "${GREEN}SUCCESS${RESET}"
    exit 0
fi

# Replace any existing timestamp_timeout values that exceed max
while IFS= read -r -d $'\0' file; do
    sed -i -E "s/timestamp_timeout=[0-9-]+/timestamp_timeout=${MAX_TIMEOUT}/g" "$file"
done < <(find /etc/sudoers.d -type f ! -name '*~' ! -name '*.bak' -print0 2>/dev/null)
sed -i -E "s/timestamp_timeout=[0-9-]+/timestamp_timeout=${MAX_TIMEOUT}/g" /etc/sudoers 2>/dev/null

# If no timestamp_timeout set at all, add it
if ! grep -roP "timestamp_timeout=" /etc/sudoers* 2>/dev/null | grep -q .; then
    echo "Defaults timestamp_timeout=${MAX_TIMEOUT}" >> /etc/sudoers
fi

# Validate
flag=1
while read -r val; do
    if [[ "$val" == "-1" ]] || (( val > MAX_TIMEOUT )); then
        flag=0
        break
    fi
done < <(grep -roP "timestamp_timeout=\K[0-9-]*" /etc/sudoers* 2>/dev/null)

if (( flag )); then
    echo -e "${GREEN}SUCCESS${RESET}"
else
    echo -e "${RED}FAILED${RESET}"
    exit 1
fi

exit 0