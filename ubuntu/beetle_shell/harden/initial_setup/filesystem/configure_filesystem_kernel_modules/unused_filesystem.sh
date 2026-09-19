#!/usr/bin/env bash
NAME="ensure unused filesystems kernel modules are not available"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$INITIAL_SETUP_RAM_STORE" ] && source "$INITIAL_SETUP_RAM_STORE" || { echo -e "${RED}FAILED${RESET}"; exit 1; }

echo ""
echo "  [MANUAL CHECK] unused filesystem kernel modules"
echo "  This check requires manual review — disabling wrong modules can be FATAL."
echo "  Run: beetle audit initial_setup to see which modules need attention."
echo ""

# Interactive prompt only if we have a terminal; otherwise default to 'y'
response="y"
if [ -t 0 ] && [ -c /dev/tty ]; then
    while true; do
        echo -e "Apply default hardening? [${GREEN}y${RESET}/${RED}n${RESET}] (default: y): "
        read -r response </dev/tty
        response="${response:-y}"
        case "${response,,}" in
            y|yes) response="y"; break ;;
            n|no)  response="n"; break ;;
            *) echo -e "${RED}Please answer y or n.${RESET}" ;;
        esac
    done
fi
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