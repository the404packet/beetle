#!/usr/bin/env bash

NAME="ensure wireless interfaces are disabled"

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

[ -f "$NETWORK_RAM_STORE" ] && source "$NETWORK_RAM_STORE"

restrict="$NS_wireless_restrict"

if [[ "$restrict" != "true" ]]; then
    echo -e "${GREEN}SUCCESS${RESET}"
    exit 0
fi

if [ -z "$(find /sys/class/net/*/ -type d -name wireless 2>/dev/null)" ]; then
    echo -e "${GREEN}SUCCESS${RESET}"
    exit 0
fi

l_dname=$(for driverdir in $(find /sys/class/net/*/ -type d -name wireless | \
    xargs -0 dirname 2>/dev/null); do
    basename "$(readlink -f "$driverdir"/device/driver/module)"
done | sort -u)

for l_mname in $l_dname; do
    if ! modprobe -n -v "$l_mname" | grep -Pq -- '^\h*install \/bin\/(true|false)'; then
        echo "install $l_mname /bin/false" >> /etc/modprobe.d/"$l_mname".conf
    fi
    if lsmod | grep -q "$l_mname" 2>/dev/null; then
        modprobe -r "$l_mname" 2>/dev/null
    fi
    if ! modprobe --showconfig | grep -Pq -- "^\h*blacklist\h+$l_mname\b"; then
        echo "blacklist $l_mname" >> /etc/modprobe.d/"$l_mname".conf
    fi
done

failed=false
for l_mname in $l_dname; do
    if ! modprobe -n -v "$l_mname" | grep -Pq -- '^\h*install \/bin\/(true|false)'; then
        failed=true
        break
    fi
    if lsmod | grep -q "$l_mname" 2>/dev/null; then
        failed=true
        break
    fi
done

if $failed; then
    echo -e "${RED}FAILED${RESET}"
    exit 1
fi

echo -e "${GREEN}SUCCESS${RESET}"
exit 0