#!/usr/bin/env bash
# state_snapshot.sh — capture current system state into JSON
#
# No Python dependency. Uses bundled jq at lib/bin/jq.

set -u

CONCERNED_JSON="/etc/beetle/concerned.json"
OUTPUT_JSON=""

# Resolve our own directory so we can find the bundled jq
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JQ="$SELF_DIR/bin/jq"
[[ -x "$JQ" ]] || JQ="$(command -v jq)"  # fallback to system jq
[[ -x "$JQ" ]] || { echo "[!] jq not found (bundled or system)"; exit 1; }

# ---------- ROOT CHECK ----------
if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    echo "[!] This script must be run as root"
    exit 1
fi

# ---------- ARGS ----------
while [[ $# -gt 0 ]]; do
    case "$1" in
        --concerned) CONCERNED_JSON="$2"; shift 2 ;;
        --output)    OUTPUT_JSON="$2";    shift 2 ;;
        *) echo "[!] Unknown argument: $1"; exit 1 ;;
    esac
done

[[ -z "$OUTPUT_JSON" ]]      && { echo "[!] --output is required"; exit 1; }
[[ ! -f "$CONCERNED_JSON" ]] && { echo "[!] Not found: $CONCERNED_JSON"; exit 1; }

# ---------- HELPERS ----------

json_escape() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    s="${s//$'\n'/\\n}"
    s="${s//$'\r'/\\r}"
    s="${s//$'\t'/\\t}"
    printf '%s' "$s"
}

jstr() { printf '"%s"' "$(json_escape "$1")"; }
jbool() { if [[ "$1" == "true" ]]; then printf 'true'; else printf 'false'; fi; }

pkg_installed() {
    dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q "install ok installed"
}

svc_enabled() { [[ "$(systemctl is-enabled "$1" 2>/dev/null)" == "enabled" ]]; }
svc_active()  { [[ "$(systemctl is-active  "$1" 2>/dev/null)" == "active"  ]]; }

km_loaded() { grep -qw "^$1" /proc/modules 2>/dev/null; }
km_exists() { modinfo "$1" &>/dev/null; }

dump_firewall() {
    case "$1" in
        ufw)      command -v ufw      &>/dev/null && ufw status verbose 2>/dev/null ;;
        iptables) command -v iptables-save &>/dev/null && iptables-save 2>/dev/null ;;
        nftables) command -v nft      &>/dev/null && nft list ruleset  2>/dev/null ;;
    esac
}

# ---------- BUILD JSON ----------
umask 077

exec 3>"$OUTPUT_JSON"

{
printf '{\n'

# -------- PACKAGES --------
printf '  "packages": [\n'
first_pkg=true
while IFS= read -r pkg; do
    [[ -z "$pkg" ]] && continue

    $first_pkg && first_pkg=false || printf ',\n'

    installed=false
    pkg_installed "$pkg" && installed=true

    printf '    {\n'
    printf '      "name": %s,\n' "$(jstr "$pkg")"
    printf '      "installed": %s,\n' "$(jbool "$installed")"
    printf '      "services": ['

    first_svc=true
    while IFS= read -r svc; do
        [[ -z "$svc" ]] && continue

        $first_svc && first_svc=false || printf ','

        enabled=false; svc_enabled "$svc" && enabled=true
        active=false;  svc_active  "$svc" && active=true

        printf '\n        { "name": %s, "enabled": %s, "active": %s }' \
            "$(jstr "$svc")" "$(jbool "$enabled")" "$(jbool "$active")"
    done < <("$JQ" -r --arg p "$pkg" '.packages[$p][]?' "$CONCERNED_JSON" 2>/dev/null)

    $first_svc && printf ']\n' || printf '\n      ]\n'
    printf '    }'
done < <("$JQ" -r '.packages | keys[]' "$CONCERNED_JSON" 2>/dev/null)

printf '\n  ],\n'

# -------- KERNEL MODULES --------
printf '  "kernel_modules": [\n'
first_km=true
while IFS= read -r km; do
    [[ -z "$km" ]] && continue

    $first_km && first_km=false || printf ',\n'

    loaded=false; km_loaded "$km" && loaded=true
    exists=false; km_exists "$km" && exists=true

    printf '    { "name": %s, "loaded": %s, "exists": %s }' \
        "$(jstr "$km")" "$(jbool "$loaded")" "$(jbool "$exists")"
done < <("$JQ" -r '.kernel_modules[].name' "$CONCERNED_JSON" 2>/dev/null)

printf '\n  ],\n'

# -------- FIREWALLS --------
printf '  "firewalls": {'
first_fw=true
while IFS= read -r fw; do
    [[ -z "$fw" ]] && continue

    $first_fw && first_fw=false || printf ','

    rules=$(dump_firewall "$fw")
    printf '\n    %s: %s' "$(jstr "$fw")" "$(jstr "$rules")"
done < <("$JQ" -r '.firewalls[]' "$CONCERNED_JSON" 2>/dev/null)

$first_fw && printf '},\n' || printf '\n  },\n'

# -------- FILES --------
printf '  "files": [\n'
first_file=true
while IFS= read -r path; do
    [[ -z "$path" ]] && continue

    $first_file && first_file=false || printf ',\n'

    if [[ ! -e "$path" ]]; then
        printf '    { "path": %s, "exists": false }' "$(jstr "$path")"
        continue
    fi

    owner=$(stat -c '%U' "$path" 2>/dev/null)
    group=$(stat -c '%G' "$path" 2>/dev/null)
    mode=$(stat -c '%a'  "$path" 2>/dev/null)

    printf '    { "path": %s, "exists": true, "owner": %s, "group": %s, "mode": %s }' \
        "$(jstr "$path")" "$(jstr "$owner")" "$(jstr "$group")" "$(jstr "$mode")"
done < <("$JQ" -r '.files[]' "$CONCERNED_JSON" 2>/dev/null)

printf '\n  ],\n'

# -------- DIRECTORIES --------
printf '  "directories": [\n'
first_dir=true
while IFS= read -r dir; do
    [[ -z "$dir" ]] && continue

    $first_dir && first_dir=false || printf ',\n'

    opts=""
    mounted=false
    if opts=$(findmnt -no OPTIONS "$dir" 2>/dev/null); then
        mounted=true
    fi

    nodev=false;  [[ ",$opts," == *,nodev,*  ]] && nodev=true
    noexec=false; [[ ",$opts," == *,noexec,* ]] && noexec=true
    nosuid=false; [[ ",$opts," == *,nosuid,* ]] && nosuid=true

    missing=""
    $nodev  || missing+="\"nodev\","
    $noexec || missing+="\"noexec\","
    $nosuid || missing+="\"nosuid\","
    missing="${missing%,}"

    printf '    {\n'
    printf '      "path": %s,\n' "$(jstr "$dir")"
    printf '      "mounted": %s,\n' "$(jbool "$mounted")"
    printf '      "options": ['
    first_opt=true
    IFS=',' read -ra opt_arr <<< "$opts"
    for o in "${opt_arr[@]}"; do
        [[ -z "$o" ]] && continue
        $first_opt && first_opt=false || printf ', '
        printf '%s' "$(jstr "$o")"
    done
    printf '],\n'
    printf '      "nodev": %s,\n' "$(jbool "$nodev")"
    printf '      "noexec": %s,\n' "$(jbool "$noexec")"
    printf '      "nosuid": %s,\n' "$(jbool "$nosuid")"
    printf '      "missing_flags": [%s]\n' "$missing"
    printf '    }'
done < <("$JQ" -r '.directories[]' "$CONCERNED_JSON" 2>/dev/null)

printf '\n  ],\n'

# -------- USERS --------
printf '  "users": [\n'
first_user=true
while IFS=: read -r name _ uid gid _ home shell; do
    [[ -z "$name" ]] && continue
    $first_user && first_user=false || printf ',\n'
    printf '    { "name": %s, "uid": %s, "gid": %s, "home": %s, "shell": %s }' \
        "$(jstr "$name")" "$uid" "$gid" "$(jstr "$home")" "$(jstr "$shell")"
done < /etc/passwd
printf '\n  ],\n'

# -------- GROUPS --------
printf '  "groups": [\n'
first_grp=true
while IFS=: read -r name _ gid members; do
    [[ -z "$name" ]] && continue
    $first_grp && first_grp=false || printf ',\n'

    member_json="["
    first_m=true
    IFS=',' read -ra mem_arr <<< "$members"
    for m in "${mem_arr[@]}"; do
        [[ -z "$m" ]] && continue
        $first_m && first_m=false || member_json+=", "
        member_json+="$(jstr "$m")"
    done
    member_json+="]"

    printf '    { "name": %s, "gid": %s, "members": %s }' \
        "$(jstr "$name")" "$gid" "$member_json"
done < /etc/group
printf '\n  ]\n'

printf '}\n'
} >&3

exec 3>&-

echo "[+] Snapshot JSON generated: $OUTPUT_JSON"
