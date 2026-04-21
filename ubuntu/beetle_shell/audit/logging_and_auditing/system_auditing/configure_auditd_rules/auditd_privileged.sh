#!/usr/bin/env bash
NAME="ensure use of privileged commands are collected"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$LOGGING_RAM_STORE" ] && source "$LOGGING_RAM_STORE" || { echo -e "${RED}NOT HARDENED${RESET}"; exit 0; }

fail=0
for PARTITION in $(findmnt -n -l -k -it \
    $(awk '/nodev/{print $2}' /proc/filesystems | paste -sd,) \
    | grep -Pv "noexec|nosuid" | awk '{print $1}'); do
    while IFS= read -r priv; do
        grep -qr "$priv" "$AR_rules_dir"/ 2>/dev/null || { fail=1; break 2; }
    done < <(find "${PARTITION}" -xdev -perm /6000 -type f 2>/dev/null)
done

[ "$fail" -eq 0 ] \
    && echo -e "${GREEN}HARDENED${RESET}" \
    || echo -e "${RED}NOT HARDENED${RESET}"
exit 0