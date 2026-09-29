#!/usr/bin/env bash

NAME="ensure avahi daemon services are not in use"

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

[ -f "$DPKG_RAM_STORE" ] && source "$DPKG_RAM_STORE"
[ -f "$SERVICES_RAM_STORE" ] && source "$SERVICES_RAM_STORE"

export DEBIAN_FRONTEND=noninteractive

category="avahi"

while IFS= read -r pkg; do
    [ -z "$pkg" ] && continue
    restrict=$(get_svc "$category" "$pkg" "restrict")
    version=$(get_svc "$category" "$pkg" "version")

    if [[ "$restrict" == "true" ]]; then
        if is_package_installed "$pkg"; then
            while IFS= read -r svc; do
                [ -z "$svc" ] && continue
                systemctl stop    "$svc" 2>/dev/null || true
                systemctl disable "$svc" 2>/dev/null || true
            done < <(get_svc_services "$category" "$pkg")

            # Do not purge avahi while a GUI session is running — gnome-keyring
            # and Seahorse dynamically load avahi shared libs; removing the package
            # mid-session causes an immediate segfault/crash.
            _gui_active=false
            if systemctl is-active display-manager.service &>/dev/null || \
               [[ -n "${DISPLAY:-}" || -n "${WAYLAND_DISPLAY:-}" || -n "${XDG_CURRENT_DESKTOP:-}" ]]; then
                _gui_active=true
            fi

            if ! $_gui_active; then
                apt-get remove --purge -y -q "$pkg" </dev/null >/dev/null 2>&1 || true
            fi
            unset_package "$pkg"
            if ! $_gui_active && live_package_installed "$pkg"; then
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