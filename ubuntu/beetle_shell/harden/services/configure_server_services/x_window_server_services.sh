#!/usr/bin/env bash

NAME="ensure X window server services are not in use"

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

[ -f "$DPKG_RAM_STORE" ] && source "$DPKG_RAM_STORE"
[ -f "$SERVICES_RAM_STORE" ] && source "$SERVICES_RAM_STORE"

export DEBIAN_FRONTEND=noninteractive

category="xwindow"

while IFS= read -r pkg; do
    [ -z "$pkg" ] && continue
    restrict=$(get_svc "$category" "$pkg" "restrict")
    version=$(get_svc "$category" "$pkg" "version")

    if [[ "$restrict" == "true" ]]; then
        if is_package_installed "$pkg"; then
            # Protect graphical desktop / display manager from being terminated
            is_gui_active=false
            if systemctl is-active display-manager.service &>/dev/null || \
               systemctl is-active gdm3 &>/dev/null || \
               systemctl is-active lightdm &>/dev/null || \
               systemctl is-active sddm &>/dev/null || \
               [[ -n "${DISPLAY:-}" ]] || [[ -n "${WAYLAND_DISPLAY:-}" ]] || \
               [[ -n "${XDG_CURRENT_DESKTOP:-}" ]]; then
                is_gui_active=true
            fi

            if $is_gui_active; then
                unset_package "$pkg"
                continue
            fi

            while IFS= read -r svc; do
                if [[ "$svc" == *"display-manager"* || "$svc" == *"gdm"* || "$svc" == *"lightdm"* || "$svc" == *"sddm"* ]]; then
                    continue
                fi
                systemctl stop "$svc" 2>/dev/null
                systemctl disable "$svc" 2>/dev/null
            done < <(get_svc_services "$category" "$pkg")

            apt-get remove --purge -y -q "$pkg" </dev/null >/dev/null 2>&1 || true
            unset_package "$pkg"
            if live_package_installed "$pkg"; then
                echo -e "${RED}FAILED${RESET}"
                exit 1
            fi
        fi
    elif [[ "$restrict" == "false" ]]; then
        if live_package_installed "$pkg"; then
            if ! is_version_ok "$pkg" "$version"; then
                apt-get upgrade -y -q "$pkg" </dev/null >/dev/null 2>&1 || true
                if ! is_version_ok "$pkg" "$version"; then
                    echo -e "${RED}FAILED${RESET}"
                    exit 1
                fi
            fi
        fi
    fi
done < <(get_svc_packages "$category")

echo -e "${GREEN}SUCCESS${RESET}"
exit 0