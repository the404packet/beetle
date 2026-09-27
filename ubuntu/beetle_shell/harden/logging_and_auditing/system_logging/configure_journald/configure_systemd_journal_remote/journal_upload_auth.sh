#!/usr/bin/env bash
NAME="ensure systemd-journal-upload authentication is configured"
GREEN="\e[32m"; RED="\e[31m"; YELLOW="\e[33m"; RESET="\e[0m"
[ -f "$LOGGING_RAM_STORE" ] && source "$LOGGING_RAM_STORE" || { echo -e "${RED}FAILED${RESET}"; exit 1; }

drop_file="${JR_upload_conf_dir}/${JR_upload_drop_file}"

missing=()
for param in URL ServerKeyFile ServerCertificateFile TrustedCertificateFile; do
    if ! grep -Pqs "^\s*${param}\s*=\s*.+" "$drop_file" 2>/dev/null; then
        missing+=("$param")
    fi
done

if [ "${#missing[@]}" -eq 0 ]; then
    echo -e "${GREEN}SUCCESS${RESET}"
    exit 0
fi

echo ""
echo -e "${YELLOW}  [MANUAL CHECK] systemd-journal-upload authentication is not configured.${RESET}"
echo "  CIS 6.2.1.4 requires a site-specific destination URL and TLS material."
echo "  Beetle cannot generate certificates or know your remote log host."
echo ""
echo "  Configure the drop-in file:"
echo "    ${drop_file}"
echo ""
echo "  Required contents:"
echo "    [Upload]"
echo "    URL=https://<your-remote-log-host>:19532"
echo "    ServerKeyFile=${JR_server_key}"
echo "    ServerCertificateFile=${JR_server_cert}"
echo "    TrustedCertificateFile=${JR_trusted_cert}"
echo ""
echo "  Missing keys: ${missing[*]}"
echo "  Then: systemctl restart systemd-journal-upload"
echo ""
echo -e "${RED}FAILED${RESET} (manual configuration required)"
exit 1
