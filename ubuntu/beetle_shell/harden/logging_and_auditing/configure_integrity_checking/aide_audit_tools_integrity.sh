#!/usr/bin/env bash
NAME="ensure cryptographic mechanisms are used to protect the integrity of audit tools"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$LOGGING_RAM_STORE" ] && source "$LOGGING_RAM_STORE" || { echo -e "${RED}FAILED${RESET}"; exit 1; }

[ -f "$AI_conf_file" ] || { echo -e "${RED}FAILED${RESET}"; exit 1; }

tool_dir=$(readlink -f /sbin)
count="$AI_tools_count"
opts="$AI_integrity_options"

# remove any existing aide tool entries then rewrite
for ((i=0; i<count; i++)); do
    t_var="AI_tool_${i}"; tool="${!t_var}"
    bin="${tool_dir}/$(basename "$tool")"
    # remove old entry
    sed -i "\|^${bin}\s|d" "$AI_conf_file" 2>/dev/null
done

# append fresh block
{
    echo ""
    echo "# Audit Tools"
    for ((i=0; i<count; i++)); do
        t_var="AI_tool_${i}"; tool="${!t_var}"
        bin="${tool_dir}/$(basename "$tool")"
        echo "${bin} ${opts}"
    done
} >> "$AI_conf_file"

# verify
aide_cmd=$(whereis aide 2>/dev/null | awk '{print $2}')
required_opts=(p i n u g s b acl xattrs sha512)
fail=0

for ((i=0; i<count; i++)); do
    t_var="AI_tool_${i}"; tool="${!t_var}"
    bin="${tool_dir}/$(basename "$tool")"
    [ -f "$bin" ] || continue
    out=$("$aide_cmd" --config "$AI_conf_file" -p f:"$bin" 2>/dev/null)
    for opt in "${required_opts[@]}"; do
        echo "$out" | grep -Psiq "(\s|\+)${opt}(\s|\+)" || { fail=1; break 2; }
    done
done

[ "$fail" -eq 0 ] \
    && echo -e "${GREEN}SUCCESS${RESET}" \
    || { echo -e "${RED}FAILED${RESET}"; exit 1; }
exit 0