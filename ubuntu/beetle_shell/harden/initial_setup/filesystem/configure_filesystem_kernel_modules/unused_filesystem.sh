#!/usr/bin/env bash
NAME="ensure unused filesystems kernel modules are not available"
GREEN="\e[32m"; RED="\e[31m"; YELLOW="\e[33m"; CYAN="\e[36m"; RESET="\e[0m"

source "${BEETLE_SHELL_ROOT:-/usr/local/bin/beetle_shell}/lib/beetle_prompt.sh"

[ -f "$INITIAL_SETUP_RAM_STORE" ] && source "$INITIAL_SETUP_RAM_STORE" || { echo -e "${RED}FAILED${RESET}"; exit 1; }

echo
echo -e "  ${YELLOW}[MANUAL CHECK]${RESET} unused filesystem kernel modules"
echo -e "  ${YELLOW}This check requires manual review — disabling wrong modules can be FATAL.${RESET}"
echo -e "  ${CYAN}Run:${RESET} beetle audit initial_setup to see which modules need attention."
echo

# Ask the user through beetle_prompt (works under the daemon, standalone, and non-interactive)
response=$(beetle_prompt "Apply default hardening?" "y")
[ "$response" = "n" ] && { echo -e "${RED}FAILED${RESET}"; exit 1; }

a_ignore=("xfs" "vfat" "ext2" "ext3" "ext4")
a_cve=("afs" "ceph" "cifs" "exfat" "ext" "fat" "fscache" "fuse" "gfs2" "nfs_common" "nfsd" "smbfs_common")
a_modprobe_config=()
a_available=()

while IFS= read -r l_config; do
    a_modprobe_config+=("$l_config")
done < <(modprobe --showconfig 2>/dev/null | grep -P '^\h*(blacklist|install)')

while IFS= read -r -d $'\0' l_dir; do
    a_available+=("$(basename "$l_dir")")
done < <(find "$(readlink -f /lib/modules/"$(uname -r)"/kernel/fs)" \
    -mindepth 1 -maxdepth 1 -type d ! -empty -print0 2>/dev/null)

while IFS= read -r l_exc; do
    grep -Pq "\b${l_exc}\b" <<< "${a_available[*]}" && \
        ! grep -Pq "\b${l_exc}\b" <<< "${a_ignore[*]}" && a_ignore+=("$l_exc")
done < <(findmnt -knD 2>/dev/null | awk '{print $2}' | sort -u)

for mod in "${a_available[@]}"; do
    [[ "$mod" =~ overlay ]] && mod="${mod::-2}"
    grep -Pq "\b${mod}\b" <<< "${a_ignore[*]}" && continue
    conf_file="${FM_modprobe_dir}/${mod}.conf"

    # Accept any /false or /true path — matches what beetle_module_harden now writes
    grep -Pq "\bblacklist\h+${mod}\b" <<< "${a_modprobe_config[*]}" || \
        printf '%s\n' "blacklist ${mod}" >> "$conf_file"
    grep -Pq "\binstall\h+${mod}\h+\S*/(false|true)\b" <<< "${a_modprobe_config[*]}" || \
        printf '%s\n' "install ${mod} /bin/false" >> "$conf_file"

    # Best-effort unload (may fail if in use; that's acceptable)
    if lsmod 2>/dev/null | grep -q "^${mod} "; then
        modprobe -r "$mod" 2>/dev/null || true
    fi
done

echo -e "${GREEN}SUCCESS${RESET}"; exit 0