#!/usr/bin/env bash
NAME="ensure cryptographic mechanisms are used to protect the integrity of audit tools"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$LOGGING_RAM_STORE" ] && source "$LOGGING_RAM_STORE" || { echo -e "${RED}NOT HARDENED${RESET}"; exit 0; }

aide_cmd=$(whereis aide 2>/dev/null | awk '{print $2}')
[ -z "$aide_cmd" ] && { echo -e "${RED}NOT HARDENED${RESET}"; exit 0; }

aide_conf=$(find -L /etc -type f -name 'aide.conf' 2>/dev/null | head -1)
[ -z "$aide_conf" ] && { echo -e "${RED}NOT HARDENED${RESET}"; exit 0; }

tool_dir=$(readlink -f /sbin)
count="$AI_tools_count"
required_opts=(p i n u g s b acl xattrs sha512)
fail=0

for ((i=0; i<count; i++)); do
    t_var="AI_tool_${i}"; tool="${!t_var}"
    bin="${tool_dir}/$(basename "$tool")"
    [ -f "$bin" ] || continue
    out=$("$aide_cmd" --config "$aide_conf" -p f:"$bin" 2>/dev/null)
    for opt in "${required_opts[@]}"; do
        echo "$out" | grep -Psiq "(\s|\+)${opt}(\s|\+)" || { fail=1; break 2; }
    done
done

[ "$fail" -eq 0 ] \
    && echo -e "${GREEN}HARDENED${RESET}" \
    || echo -e "${RED}NOT HARDENED${RESET}"
exit 0