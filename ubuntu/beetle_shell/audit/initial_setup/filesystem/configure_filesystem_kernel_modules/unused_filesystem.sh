#!/usr/bin/env bash
NAME="ensure unused filesystems kernel modules are not available"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$INITIAL_SETUP_RAM_STORE" ] && source "$INITIAL_SETUP_RAM_STORE" || { echo -e "${RED}NOT HARDENED${RESET}"; exit 0; }

a_ignore=("xfs" "vfat" "ext2" "ext3" "ext4")
a_cve=("afs" "ceph" "cifs" "exfat" "ext" "fat" "fscache" "fuse" "gfs2" "nfs_common" "nfsd" "smbfs_common")
a_modprobe_config=()
a_available=()
fail=0

while IFS= read -r l_config; do
    a_modprobe_config+=("$l_config")
done < <(modprobe --showconfig 2>/dev/null | grep -P '^\h*(blacklist|install)')

while IFS= read -r -d $'\0' l_dir; do
    a_available+=("$(basename "$l_dir")")
done < <(find "$(readlink -f /lib/modules/"$(uname -r)"/kernel/fs)" \
    -mindepth 1 -maxdepth 1 -type d ! -empty -print0 2>/dev/null)

while IFS= read -r l_exc; do
    grep -Pq "\b${l_exc}\b" <<< "${a_cve[*]}" && { fail=1; break; }
    grep -Pq "\b${l_exc}\b" <<< "${a_available[*]}" && \
        ! grep -Pq "\b${l_exc}\b" <<< "${a_ignore[*]}" && a_ignore+=("$l_exc")
done < <(findmnt -knD 2>/dev/null | awk '{print $2}' | sort -u)

for mod in "${a_available[@]}"; do
    [[ "$mod" =~ overlay ]] && mod="${mod::-2}"
    grep -Pq "\b${mod}\b" <<< "${a_ignore[*]}" && continue
    grep -Pq "\bblacklist\h+${mod}\b" <<< "${a_modprobe_config[*]}" || { fail=1; break; }
    grep -Pq "\binstall\h+${mod}\h+(\/usr)?\/bin\/(false|true)\b" <<< "${a_modprobe_config[*]}" || { fail=1; break; }
    lsmod 2>/dev/null | grep -q "$mod" && { fail=1; break; }
done

[ "$fail" -eq 0 ] \
    && echo -e "${GREEN}HARDENED${RESET}" \
    || echo -e "${RED}NOT HARDENED${RESET}"
exit 0