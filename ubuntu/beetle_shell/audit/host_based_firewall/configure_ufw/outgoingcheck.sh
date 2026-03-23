#!/usr/bin/env bash

NAME='ufw outgoing check'
SEVERITY="basic"


flag=1

# approved outbound ports
approved_ports=(
  "53/tcp"
  "53/udp"
  "80/tcp"
  "443/tcp"
  "123/udp"
  "853/tcp"
  "22/tcp"
  "9418/tcp"
  "873/tcp"
  "2376/tcp"
  "8772/udp"
  "4789/udp"
)

# check default outgoing policy = deny
if ! ufw status verbose | grep -q "deny (outgoing)"; then
    flag=0
fi

# collect all allowed outbound ports from ufw
mapfile -t current_ports < <(ufw status | awk '/ALLOW OUT/ {print $1}')

# check every current port is approved
for p in "${current_ports[@]}"; do
    found=0
    for ap in "${approved_ports[@]}"; do
        if [[ "$p" == "$ap" ]]; then
            found=1
            break
        fi
    done
    if (( ! found )); then
        flag=0
        break
    fi
done

# also ensure all approved ports exist
for ap in "${approved_ports[@]}"; do
    if ! printf '%s\n' "${current_ports[@]}" | grep -qx "$ap"; then
        flag=0
        break
    fi
done

if (( flag )); then
    echo -e "${GREEN}HARDENED${RESET}"
else
    echo -e "${RED}NOT HARDENED${RESET}"
fi

exit 0
