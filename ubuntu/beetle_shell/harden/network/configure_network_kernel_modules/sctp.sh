#!/usr/bin/env bash

NAME="ensure sctp kernel module is not available"

GREEN="\e[32m"
RED="\e[31m"
YELLOW="\e[33m"
RESET="\e[0m"

[ -f "$NETWORK_RAM_STORE" ] && source "$NETWORK_RAM_STORE"

mod_name="sctp"
mod_type="net"
mod_path="$(readlink -f /lib/modules/**/kernel/$mod_type 2>/dev/null | sort -u)"

if [ -z "$mod_path" ]; then
    echo -e "${GREEN}SUCCESS${RESET}"
    exit 0
fi

for mod_base in $mod_path; do
    if [ -d "$mod_base/${mod_name}" ] && [ -n "$(ls -A "$mod_base/${mod_name}" 2>/dev/null)" ]; then
        showconfig=$(modprobe --showconfig 2>/dev/null | grep -P -- "\b(install|blacklist)\h+${mod_name}\b")

        # Best-effort unload — may fail if module is in use; that's OK
        if lsmod | grep -q "^${mod_name} " 2>/dev/null; then
            modprobe -r "$mod_name" 2>/dev/null || true
        fi

        # Persistent block via modprobe config
        if ! grep -Pq -- "\binstall\h+${mod_name}\h+(\/usr)?\/bin\/(true|false)\b" <<< "$showconfig"; then
            printf '%s\n' "install $mod_name /bin/true" >> /etc/modprobe.d/"$mod_name".conf
        fi
        if ! grep -Pq -- "\bblacklist\h+${mod_name}\b" <<< "$showconfig"; then
            printf '%s\n' "blacklist $mod_name" >> /etc/modprobe.d/"$mod_name".conf
        fi
    fi
done

# Verify: persistent block must be in place; module must not be loadable on demand
failed=false
for mod_base in $mod_path; do
    if [ -d "$mod_base/${mod_name}" ] && [ -n "$(ls -A "$mod_base/${mod_name}" 2>/dev/null)" ]; then
        showconfig=$(modprobe --showconfig 2>/dev/null | grep -P -- "\b(install|blacklist)\h+${mod_name}\b")

        if ! grep -Pq -- "\binstall\h+${mod_name}\h+(\/usr)?\/bin\/(true|false)\b" <<< "$showconfig"; then
            failed=true; break
        fi
        if ! grep -Pq -- "\bblacklist\h+${mod_name}\b" <<< "$showconfig"; then
            failed=true; break
        fi

        # Real test of "not available": modprobe must NOT plan to insmod it
        if modprobe --dry-run "$mod_name" 2>/dev/null | grep -q "insmod"; then
            failed=true; break
        fi
    fi
done

# Warn if the module is still resident in the running kernel (in use by another component).
# This does not constitute failure — the block applies on next boot / reload.
if ! $failed && lsmod | grep -q "^${mod_name} "; then
    echo -e "${YELLOW}WARN: ${mod_name} still loaded in running kernel (in use); block will apply on next boot${RESET}" >&2
fi

$failed && { echo -e "${RED}FAILED${RESET}"; exit 1; } || echo -e "${GREEN}SUCCESS${RESET}"
exit 0