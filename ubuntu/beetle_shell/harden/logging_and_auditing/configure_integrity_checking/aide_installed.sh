#!/usr/bin/env bash
NAME="ensure AIDE is installed"
GREEN="\e[32m"; RED="\e[31m"; YELLOW="\e[33m"; RESET="\e[0m"
[ -f "$DPKG_RAM_STORE" ]    && source "$DPKG_RAM_STORE"
[ -f "$LOGGING_RAM_STORE" ] && source "$LOGGING_RAM_STORE" || { echo -e "${RED}FAILED${RESET}"; exit 1; }

export DEBIAN_FRONTEND=noninteractive

# Ensure both packages are installed
count="$AI_pkg_count"
for ((i=0; i<count; i++)); do
    n_var="AI_pkg_${i}_name"; pkg="${!n_var}"
    if ! is_package_installed "$pkg"; then
        apt-get install -y -q "$pkg" </dev/null >/dev/null 2>&1 \
            || { echo -e "${RED}FAILED${RESET}"; exit 1; }
    fi
done

# The AIDE database is initialized as a one-time follow-up step (CIS 6.3.1
# treats it as manual). Do not block the harden run waiting for aideinit.
if [ ! -f "$AI_db_active" ]; then
    echo ""
    echo -e "${YELLOW}  [FOLLOW-UP] AIDE packages installed, but the AIDE database${RESET}"
    echo -e "${YELLOW}  has not been initialized yet. Run once as root:${RESET}"
    echo ""
    echo "      sudo aideinit"
    echo "      sudo mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db"
    echo ""
    echo -e "${YELLOW}  This may take several minutes (or hours on WSL).${RESET}"
    echo ""
fi

echo -e "${GREEN}SUCCESS${RESET}"
exit 0