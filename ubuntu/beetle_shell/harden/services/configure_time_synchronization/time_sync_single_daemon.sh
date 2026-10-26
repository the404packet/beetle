#!/usr/bin/env bash

NAME="ensure a single time synchronization daemon is in use"

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

[ -f "$DPKG_RAM_STORE" ] && source "$DPKG_RAM_STORE"
[ -f "$SERVICES_RAM_STORE" ] && source "$SERVICES_RAM_STORE"

export DEBIAN_FRONTEND=noninteractive

daemon_count="${TS_daemon_count:-0}"
default_name="${TS_default:-}"

# ── Gather state of every daemon ──
active_list=()      # indexes of daemons that are active or enabled
default_idx=-1      # index whose name matches $TS_default
for ((i=0; i<daemon_count; i++)); do
    name_var="TS_daemon_${i}_name"
    service_var="TS_daemon_${i}_service"
    name="${!name_var}"
    service="${!service_var}"
    [ -z "$service" ] && continue

    if [ "$name" == "$default_name" ]; then
        default_idx="$i"
    fi

    is_enabled=$(systemctl is-enabled "$service" 2>/dev/null)
    is_active=$(systemctl is-active   "$service" 2>/dev/null)

    if [[ "$is_enabled" == "enabled" ]] || [[ "$is_active" == "active" ]]; then
        active_list+=("$i")
    fi
done

# ── Nothing running or enabled → install + enable the default ──
if [[ "${#active_list[@]}" -eq 0 ]]; then
    if [ "$default_idx" -lt 0 ]; then
        echo -e "${RED}FAILED${RESET}"
        exit 1
    fi

    d_pkg_var="TS_daemon_${default_idx}_package"
    d_svc_var="TS_daemon_${default_idx}_service"
    d_pkg="${!d_pkg_var}"
    d_svc="${!d_svc_var}"

    if ! is_package_installed "$d_pkg"; then
        apt-get install -y -q "$d_pkg" </dev/null >/dev/null 2>&1 || true
        if ! live_package_installed "$d_pkg"; then
            echo -e "${RED}FAILED${RESET}"
            exit 1
        fi
    fi

    systemctl unmask        "$d_svc" 2>/dev/null || true
    systemctl --now enable  "$d_svc" 2>/dev/null || true

    if [[ "$(systemctl is-active "$d_svc" 2>/dev/null)" != "active" ]]; then
        echo -e "${RED}FAILED${RESET}"
        exit 1
    fi
    echo -e "${GREEN}SUCCESS${RESET}"
    exit 0
fi

# ── Exactly one active/enabled → leave it alone ──
if [[ "${#active_list[@]}" -eq 1 ]]; then
    echo -e "${GREEN}SUCCESS${RESET}"
    exit 0
fi

# ── More than one → pick winner (prefer default), disable/mask the rest ──
winner="${active_list[0]}"
if [ "$default_idx" -ge 0 ]; then
    for idx in "${active_list[@]}"; do
        if [ "$idx" == "$default_idx" ]; then
            winner="$default_idx"
            break
        fi
    done
fi

for idx in "${active_list[@]}"; do
    [ "$idx" == "$winner" ] && continue

    svc_var="TS_daemon_${idx}_service"
    svc="${!svc_var}"
    [ -z "$svc" ] && continue

    systemctl stop    "$svc" 2>/dev/null || true
    systemctl disable "$svc" 2>/dev/null || true
    systemctl mask    "$svc" 2>/dev/null || true
done

# Ensure the winner is enabled + active
w_svc_var="TS_daemon_${winner}_service"
w_svc="${!w_svc_var}"
systemctl unmask       "$w_svc" 2>/dev/null || true
systemctl --now enable "$w_svc" 2>/dev/null || true

# ── Verify: exactly one enabled AND active ──
final_count=0
for ((i=0; i<daemon_count; i++)); do
    service_var="TS_daemon_${i}_service"
    service="${!service_var}"
    [ -z "$service" ] && continue

    is_enabled=$(systemctl is-enabled "$service" 2>/dev/null)
    is_active=$(systemctl is-active   "$service" 2>/dev/null)

    if [[ "$is_enabled" == "enabled" ]] || [[ "$is_active" == "active" ]]; then
        ((final_count++))
    fi
done

if [[ "$final_count" -eq 1 ]]; then
    echo -e "${GREEN}SUCCESS${RESET}"
    exit 0
fi

echo -e "${RED}FAILED${RESET}"
exit 1
