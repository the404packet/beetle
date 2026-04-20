#!/usr/bin/env bash
NAME="ensure rsyslog is configured to send logs to a remote log host"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$LOGGING_RAM_STORE" ] && source "$LOGGING_RAM_STORE" || { echo -e "${RED}FAILED${RESET}"; exit 1; }

local_ip=$(ip addr show | awk '/inet / && !/127.0.0.1/{print $2}' | cut -d/ -f1 | head -1)
[ -z "$local_ip" ] && { echo -e "${RED}FAILED${RESET}"; exit 1; }

drop_file="${RS_config_dir}/${RS_drop_file}"
mkdir -p "$RS_config_dir"

echo ""
echo "  [MANUAL CHECK] rsyslog remote log host"
echo "  Detected IP : $local_ip"
echo "  Will write  :"
echo "    *.* action(type=\"omfwd\" target=\"${local_ip}\" port=\"${RS_remote_port}\" protocol=\"${RS_remote_protocol}\""
echo "     action.resumeRetryCount=\"${RS_resume_retry}\""
echo "     queue.type=\"${RS_queue_type}\" queue.size=\"${RS_queue_size}\")"
echo ""
echo -n "  Press ENTER to apply, or type 'no' to handle manually: "
read -r response

if [ "$response" = "no" ]; then
    echo -e "${RED}FAILED${RESET}"; exit 1
fi

cat >> "$drop_file" <<EOF

*.* action(type="omfwd" target="${local_ip}" port="${RS_remote_port}" protocol="${RS_remote_protocol}"
 action.resumeRetryCount="${RS_resume_retry}"
 queue.type="${RS_queue_type}" queue.size="${RS_queue_size}")
EOF

systemctl reload-or-restart "$RS_service" 2>/dev/null || true

found=$(grep -rPHsi '^\s*([^#]+\s+)?action\(([^#]+\s+)?\btarget=' \
        "$RS_config_file" "$RS_config_dir"/ 2>/dev/null | head -1)

[ -n "$found" ] \
    && echo -e "${GREEN}SUCCESS${RESET}" \
    || { echo -e "${RED}FAILED${RESET}"; exit 1; }
exit 0