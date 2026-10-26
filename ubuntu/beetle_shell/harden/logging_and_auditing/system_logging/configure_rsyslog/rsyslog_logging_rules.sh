#!/usr/bin/env bash
NAME="ensure rsyslog logging is configured"
GREEN="\e[32m"; RED="\e[31m"; YELLOW="\e[33m"; RESET="\e[0m"
[ -f "$LOGGING_RAM_STORE" ] && source "$LOGGING_RAM_STORE" || { echo -e "${RED}FAILED${RESET}"; exit 1; }

[ "${LJ_preferred_logging_system:-journald}" != "rsyslog" ] && { echo -e "${GREEN}SUCCESS${RESET}"; exit 0; }

if [ -z "$RS_config_dir" ] || [ -z "$RS_drop_file" ]; then
    echo -e "${RED}FAILED${RESET} (config paths not set)"
    exit 1
fi

export DEBIAN_FRONTEND=noninteractive

if ! dpkg-query -W -f='${Status}' "$RS_package" 2>/dev/null | grep -q "install ok installed"; then
    apt-get install -y -q "$RS_package" </dev/null >/dev/null 2>&1 || true
fi

drop_file="${RS_config_dir}/${RS_drop_file}"
mkdir -p "$RS_config_dir"

count="$RS_rules_count"

if [ -t 0 ] && [ -c /dev/tty ]; then
    echo ""
    echo -e "${YELLOW}  [INFO] Writing the following rules to $drop_file:${RESET}"
    for ((i=0; i<count; i++)); do
        r_var="RS_${i}_rule"; d_var="RS_${i}_dest"
        echo "    ${!r_var}  ${!d_var}"
    done
    echo ""
    echo -n "  Apply? [y/n] (default: y): "
    read -r response </dev/tty
    response="${response:-y}"
    if [[ "${response,,}" != "y" ]]; then
        echo -e "${RED}FAILED${RESET} (user declined)"
        exit 1
    fi
fi

{
    for ((i=0; i<count; i++)); do
        r_var="RS_${i}_rule"; d_var="RS_${i}_dest"
        echo "${!r_var}  ${!d_var}"
    done
} > "$drop_file"

systemctl reload-or-restart "$RS_service" 2>/dev/null || true

fail=0
for ((i=0; i<count; i++)); do
    dest_var="RS_${i}_dest"; dest="${!dest_var}"
    dest_clean="${dest#-}"
    grep -rqPs "^\s*[^#].*${dest_clean//\//\\/}" \
        "$RS_config_file" "$RS_config_dir"/ 2>/dev/null || fail=1
done

[ "$fail" -eq 0 ] \
    && echo -e "${GREEN}SUCCESS${RESET}" \
    || { echo -e "${RED}FAILED${RESET}"; exit 1; }
exit 0
