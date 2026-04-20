#!/usr/bin/env bash
NAME="ensure systemd-journal-upload authentication is configured"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$LOGGING_RAM_STORE" ] && source "$LOGGING_RAM_STORE" || { echo -e "${RED}FAILED${RESET}"; exit 1; }

# auto-detect primary non-loopback inet IP
local_ip=$(ip addr show | awk '/inet / && !/127.0.0.1/{print $2}' | cut -d/ -f1 | head -1)

if [ -z "$local_ip" ]; then
    echo -e "${RED}FAILED${RESET}"; exit 1
fi

echo -n "  Press ENTER to apply, or type 'no' to handle manually: "
read -r response

if [ "$response" = "no" ]; then
    echo -e "${RED}FAILED${RESET}"; exit 1
fi

conf_dir="$JR_upload_conf_dir"
drop_file="${conf_dir}/$JR_upload_drop_file"
mkdir -p "$conf_dir"

{
    echo "[Upload]"
    echo "URL=https://${local_ip}"
    echo "ServerKeyFile=$JR_server_key"
    echo "ServerCertificateFile=$JR_server_cert"
    echo "TrustedCertificateFile=$JR_trusted_cert"
} > "$drop_file"

chmod 600 "$drop_file"
systemctl reload-or-restart systemd-journal-upload 2>/dev/null || true

# verify
analyze_cmd="$(readlink -f /bin/systemd-analyze)"
conf="systemd/journal-upload.conf"
fail=0
for param in URL ServerKeyFile ServerCertificateFile TrustedCertificateFile; do
    found=$("$analyze_cmd" cat-config "$conf" 2>/dev/null \
            | grep -Ps "^\s*${param}\s*=\s*.+" | tail -1)
    [ -z "$found" ] && { echo "  FAIL: $param still not set after harden"; fail=1; }
done

[ "$fail" -eq 0 ] && echo -e "${GREEN}SUCCESS${RESET}" || { echo -e "${RED}FAILED${RESET}"; exit 1; }
exit 0