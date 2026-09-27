#!/usr/bin/env bash
NAME="ensure journald log file rotation is configured"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$LOGGING_RAM_STORE" ] && source "$LOGGING_RAM_STORE" || { echo -e "${RED}FAILED${RESET}"; exit 1; }

[ "${LJ_preferred_logging_system:-journald}" != "journald" ] && { echo -e "${GREEN}SUCCESS${RESET}"; exit 0; }

drop_dir="$LJ_config_drop_dir"
drop_file="${drop_dir}/60-cis-rotation.conf"
count="$LJ_rot_count"

if [ -z "$drop_dir" ] || [ -z "$drop_file" ]; then
    echo -e "${RED}FAILED${RESET} (config paths not set)"
    exit 1
fi

mkdir -p "$drop_dir"

{
    echo "[Journal]"
    for ((i=0; i<count; i++)); do
        k_var="LJ_rot_${i}_key";   k="${!k_var}"
        v_var="LJ_rot_${i}_value"; v="${!v_var}"
        [ -n "$k" ] && echo "${k}=${v}"
    done
} > "$drop_file"

systemctl reload-or-restart systemd-journald 2>/dev/null || true

fail=0
for ((i=0; i<count; i++)); do
    k_var="LJ_rot_${i}_key"; k="${!k_var}"
    [ -z "$k" ] && continue
    if ! grep -Pqs "^\s*${k}\s*=\s*.+" "$drop_file"; then
        echo "  FAIL: $k not present in $drop_file"
        fail=1
    fi
done

[ "$fail" -eq 0 ] \
    && echo -e "${GREEN}SUCCESS${RESET}" \
    || { echo -e "${RED}FAILED${RESET}"; exit 1; }
exit 0