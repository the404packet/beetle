#!/usr/bin/env bash

NAME="ensure MTA is not listening on non-loopback interfaces"
SEVERITY="basic"

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

fail_reasons=()

# Ports commonly used by MTAs
ports=("25" "465" "587")

# Check listening ports
for port in "${ports[@]}"; do
    if ss -plntu | grep -P -- ":$port\b" | \
       grep -Pvq -- "\h+(127\.0\.0\.1|\[?::1\]?):$port\b"; then
        fail_reasons+=("Port $port is listening on a non-loopback interface")
    fi
done

# Detect MTA configuration binding
interfaces=""

if command -v postconf &>/dev/null; then
    interfaces=$(postconf -n inet_interfaces 2>/dev/null | awk '{print $3}')
elif command -v exim &>/dev/null; then
    interfaces=$(exim -bP local_interfaces 2>/dev/null)
elif command -v sendmail &>/dev/null; then
    interfaces=$(grep -i "DaemonPortOptions" /etc/mail/sendmail.cf 2>/dev/null | \
                 grep -oP '(?<=Addr=)[^,]+')
fi

# Evaluate interface binding
if [[ -n "$interfaces" ]]; then
    if echo "$interfaces" | grep -Pqi '\ball\b'; then
        fail_reasons+=("MTA is bound to all network interfaces")
    elif ! echo "$interfaces" | grep -Pqi '(127\.0\.0\.1|::1|loopback-only|loopbackonly)'; then
        fail_reasons+=("MTA is bound to non-loopback interface: $interfaces")
    fi
fi

# Final result
if [[ ${#fail_reasons[@]} -eq 0 ]]; then
    echo -e "${GREEN}HARDENED${RESET}"
else
    echo -e "${RED}NOT HARDENED${RESET}"
    for reason in "${fail_reasons[@]}"; do
        echo "$reason"
    done
fi

exit 0
