#!/usr/bin/env bash
NAME="ensure GDM is removed"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$DPKG_RAM_STORE" ]          && source "$DPKG_RAM_STORE"
[ -f "$INITIAL_SETUP_RAM_STORE" ] && source "$INITIAL_SETUP_RAM_STORE" || { echo -e "${RED}FAILED${RESET}"; exit 1; }

POLICY_FILE="/usr/sbin/policy-rc.d"
POLICY_BACKUP=""

# Ask the user a yes/no question. Default is NO (destructive action).
confirm() {
    local text="$1" raw ans
    if [[ "${BEETLE_INTERACTIVE:-0}" == "1" ]] && [ -e /dev/fd/4 ]; then
        echo "PROMPT:$text"
        if read -r raw <&4; then
            ans="${raw#ANSWER:}"
            [[ "$ans" =~ ^[Yy]$ ]] && return 0
        fi
        return 1
    elif [ -t 0 ]; then
        read -r -p "$text [y/n]: " ans
        [[ "$ans" =~ ^[Yy]$ ]] && return 0
        return 1
    fi
    return 1
}

# True if a graphical (X11/Wayland/Mir) login session is currently running.
graphical_session_active() {
    local id type
    while read -r id _; do
        [ -n "$id" ] || continue
        type="$(loginctl show-session "$id" -p Type --value 2>/dev/null)"
        case "$type" in x11|wayland|mir) return 0 ;; esac
    done < <(loginctl list-sessions --no-legend 2>/dev/null)
    return 1
}

# Put back whatever policy-rc.d looked like before we touched it.
restore_policy() {
    rm -f "$POLICY_FILE"
    if [ -n "$POLICY_BACKUP" ] && [ -f "$POLICY_BACKUP" ]; then
        mv -f "$POLICY_BACKUP" "$POLICY_FILE"
    fi
    return 0
}

# Already removed: nothing to do, no need to ask.
if ! is_package_installed "$GD_package"; then
    echo -e "${GREEN}SUCCESS${RESET}"
    exit 0
fi

# Explain what will happen, then ask (one line: PROMPT:/ANSWER: is line-based).
if ! confirm "This will remove GDM ($GD_package), the graphical login screen. Your current desktop session keeps running until you log out or reboot, but after that the machine will boot to a text console and you will not be able to log in graphically. Proceed?"; then
    echo -e "${RED}FAILED${RESET}"
    exit 1
fi

# policy-rc.d exiting 101 stops maintainer scripts from stopping services,
# so the purge does not end the user's graphical session.
if [ -e "$POLICY_FILE" ]; then
    POLICY_BACKUP="$(mktemp)"
    cp -p "$POLICY_FILE" "$POLICY_BACKUP"
fi
trap restore_policy EXIT
printf '#!/bin/sh\nexit 101\n' > "$POLICY_FILE"
chmod 755 "$POLICY_FILE"

# No autoremove: it is system-wide and can strip unrelated desktop packages.
DEBIAN_FRONTEND=noninteractive apt-get purge -y "$GD_package" >/dev/null 2>&1

if is_package_installed "$GD_package"; then
    echo -e "${RED}FAILED${RESET}"
    exit 1
fi

# GDM stays alive in the running session until the next boot: flag a reboot.
if graphical_session_active; then
    touch /var/run/reboot-required
fi

echo -e "${GREEN}SUCCESS${RESET}"
exit 0