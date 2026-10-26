#!/usr/bin/env bash
NAME="ensure cryptographic mechanisms are used to protect the integrity of audit tools"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$LOGGING_RAM_STORE" ] && source "$LOGGING_RAM_STORE" || { echo -e "${RED}FAILED${RESET}"; exit 1; }

export DEBIAN_FRONTEND=noninteractive

if ! dpkg-query -W -f='${Status}' aide 2>/dev/null | grep -q "install ok installed"; then
    apt-get install -y -q aide aide-common </dev/null >/dev/null 2>&1 || true
fi

if [ -z "$AI_conf_file" ] || [ ! -f "$AI_conf_file" ]; then
    echo -e "${RED}FAILED${RESET} (aide.conf not found)"
    exit 1
fi

tool_dir=$(readlink -f /sbin)
[ -z "$tool_dir" ] && tool_dir="/sbin"

count="$AI_tools_count"
opts="$AI_integrity_options"

for ((i=0; i<count; i++)); do
    t_var="AI_tool_${i}"; tool="${!t_var}"
    [ -z "$tool" ] && continue
    bin="${tool_dir}/$(basename "$tool")"
    [ -z "$bin" ] || [ "$bin" = "/" ] && continue
    sed -i "\|^${bin}\s|d" "$AI_conf_file" 2>/dev/null || true
done

sed -i '/^# Audit Tools$/d' "$AI_conf_file" 2>/dev/null || true

{
    for ((i=0; i<count; i++)); do
        t_var="AI_tool_${i}"; tool="${!t_var}"
        [ -z "$tool" ] && continue
        bin="${tool_dir}/$(basename "$tool")"
        [ -f "$bin" ] || continue
        echo "${bin} ${opts}"
    done
} >> "$AI_conf_file"

aide_cmd=$(whereis aide 2>/dev/null | awk '{print $2}')
if [ -z "$aide_cmd" ]; then
    echo -e "${RED}FAILED${RESET} (aide not found after install)"
    exit 1
fi

required_opts=(p i n u g s b acl xattrs sha512)
fail=0

for ((i=0; i<count; i++)); do
    t_var="AI_tool_${i}"; tool="${!t_var}"
    [ -z "$tool" ] && continue
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
