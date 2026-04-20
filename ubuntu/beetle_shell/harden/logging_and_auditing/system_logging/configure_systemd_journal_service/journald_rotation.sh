#!/usr/bin/env bash
NAME="ensure journald log file rotation is configured"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$LOGGING_RAM_STORE" ] && source "$LOGGING_RAM_STORE" || { echo -e "${RED}FAILED${RESET}"; exit 1; }

drop_dir="$LJ_config_drop_dir"
drop_file="${drop_dir}/60-cis-rotation.conf"
count="$LJ_rot_count"

mkdir -p "$drop_dir"

# build [Journal] block
{ 
  for ((i=0; i<count; i++)); do
      k_var="LJ_rot_${i}_key";   k="${!k_var}"
      v_var="LJ_rot_${i}_value"; v="${!v_var}"
      echo "${k}=${v}"
  done
} > "$drop_file"

systemctl reload-or-restart systemd-journald 2>/dev/null || true

# verify
fail=0
analyze_cmd="$(readlink -f /bin/systemd-analyze)"
for ((i=0; i<count; i++)); do
    k_var="LJ_rot_${i}_key"; k="${!k_var}"
    found=$("$analyze_cmd" cat-config systemd/journald.conf 2>/dev/null \
             | grep -Ps "^\s*${k}\s*=\s*.+" | tail -1)
    [ -z "$found" ] && { echo "  FAIL: $k still not set after harden"; fail=1; }
done

[ "$fail" -eq 0 ] && echo -e "${GREEN}SUCCESS${RESET}" || { echo -e "${RED}FAILED${RESET}"; exit 1; }
exit 0