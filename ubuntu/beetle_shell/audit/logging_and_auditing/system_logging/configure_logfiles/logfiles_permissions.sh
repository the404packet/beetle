#!/usr/bin/env bash
NAME="ensure access to all logfiles has been configured"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$LOGGING_RAM_STORE" ] && source "$LOGGING_RAM_STORE" || { echo -e "${RED}NOT HARDENED${RESET}"; exit 0; }

fail=0
count="$LP_rules_count"

f_get_rule() {
    local fname="$1" dirname
    dirname="$(dirname "$fname")"
    basename="$(basename "$fname")"
    for ((i=0; i<count; i++)); do
        mt_var="LP_${i}_match_type"; mt="${!mt_var}"
        pat_var="LP_${i}_pattern";   pat="${!pat_var}"
        case "$mt" in
            dir_pattern)
                grep -Pq -- "$pat" <<< "$dirname" || continue ;;
            basename)
                [[ "$basename" =~ ^($pat)$ ]] || continue ;;
            default)
                ;;
            *)  continue ;;
        esac
        # matched — export rule vars
        rule_index=$i
        return 0
    done
    rule_index=$(( count - 1 ))  # fallback to default
}

while IFS= read -r -d $'\0' l_file; do
    while IFS=: read -r l_fname l_mode l_user l_group; do
        f_get_rule "$l_fname"
        i=$rule_index
        pm_var="LP_${i}_perm_mask"; perm_mask="${!pm_var}"
        ow_var="LP_${i}_owner";     l_aowner="${!ow_var}"
        gr_var="LP_${i}_group";     l_agroup="${!gr_var}"

        [ $(( 8#$l_mode & 8#$perm_mask )) -gt 0 ]  && { fail=1; break; }
        [[ ! "$l_user"  =~ $l_aowner ]]             && { fail=1; break; }
        [[ ! "$l_group" =~ $l_agroup ]]             && { fail=1; break; }
    done < <(stat -Lc '%n:%#a:%U:%G' "$l_file")
done < <(find -L "$LP_search_dir" -type f \( -perm /0137 -o ! -user root -o ! -group root \) -print0)

[ "$fail" -eq 0 ] \
    && echo -e "${GREEN}HARDENED${RESET}" \
    || echo -e "${RED}NOT HARDENED${RESET}"
exit 0