#!/usr/bin/env bash
NAME="ensure rsyslog logging is configured"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$LOGGING_RAM_STORE" ] && source "$LOGGING_RAM_STORE" || { echo -e "${RED}FAILED${RESET}"; exit 1; }

drop_file="${RS_config_dir}/${RS_drop_file}"
mkdir -p "$RS_config_dir"

echo ""
echo "  [MANUAL CHECK] rsyslog logging rules"
echo "  Will write the following rules to $drop_file:"
count="$RS_rules_count"
for ((i=0; i<count; i++)); do
    r_var="RS_${i}_rule"; d_var="RS_${i}_dest"
    echo "    ${!r_var}  ${!d_var}"
done
echo ""
echo -n "  Press ENTER to apply, or type 'no' to handle manually: "
read -r response

if [ "$response" = "no" ]; then
    echo -e "${RED}FAILED${RESET}"; exit 1
fi

for ((i=0; i<count; i++)); do
    r_var="RS_${i}_rule"; d_var="RS_${i}_dest"
    echo "${!r_var}  ${!d_var}" >> "$drop_file"
done

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