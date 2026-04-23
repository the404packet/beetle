#!/usr/bin/env bash

CONCERNED_JSON="/etc/beetle/concerned.json"
OUTPUT_JSON=""

# ---------- ROOT CHECK ----------
if [[ "$EUID" -ne 0 ]]; then
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
    printf '%s' "$1" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | awk '{printf "%s\\n", $0}' | sed 's/\\n$//'
}

pkg_installed() {
    dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q "install ok installed" && echo "true" || echo "false"
}

svc_enabled() {
    [[ "$(systemctl is-enabled "$1" 2>/dev/null)" == "enabled" ]] && echo "true" || echo "false"
}

svc_active() {
    [[ "$(systemctl is-active "$1" 2>/dev/null)" == "active" ]] && echo "true" || echo "false"
}

km_loaded() {
    grep -qw "^$1" /proc/modules 2>/dev/null && echo "true" || echo "false"
}

km_exists() {
    modinfo "$1" &>/dev/null && echo "true" || echo "false"
}

fw_rules() {
    case "$1" in
        ufw) command -v ufw &>/dev/null && ufw status verbose 2>/dev/null || echo "" ;;
        iptables) command -v iptables-save &>/dev/null && iptables-save 2>/dev/null || echo "" ;;
        nftables) command -v nft &>/dev/null && nft list ruleset 2>/dev/null || echo "" ;;
    esac
}

file_stat() {
    [[ ! -e "$1" ]] && { echo ""; return; }
    case "$2" in
        owner) stat -c '%U' "$1" ;;
        group) stat -c '%G' "$1" ;;
        mode)  stat -c '%a' "$1" ;;
    esac
}

# ---------- JSON BUILD (SAFE) ----------

OUT=$(
python3 - <<EOF
import json, subprocess, os

conf = "$CONCERNED_JSON"

data = json.load(open(conf))

result = {}

# -------- PACKAGES --------
pkgs = []
for pkg, services in data.get("packages", {}).items():
    try:
        subprocess.check_output(["dpkg","-s",pkg], stderr=subprocess.DEVNULL)
        installed = True
    except:
        installed = False

    svc_list = []
    for s in services:
        def run(cmd):
            try:
                return subprocess.check_output(cmd, stderr=subprocess.DEVNULL).decode().strip()
            except:
                return "unknown"

        svc_list.append({
            "name": s,
            "enabled": run(["systemctl","is-enabled",s]) == "enabled",
            "active": run(["systemctl","is-active",s]) == "active"
        })

    pkgs.append({
        "name": pkg,
        "installed": installed,
        "services": svc_list
    })

result["packages"] = pkgs

# -------- KERNEL --------
kmods = []
loaded = subprocess.check_output(["lsmod"]).decode()

for m in data.get("kernel_modules", []):
    name = m["name"]
    exists = subprocess.call(["modinfo", name], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL) == 0

    kmods.append({
        "name": name,
        "loaded": name in loaded,
        "exists": exists
    })

result["kernel_modules"] = kmods

# -------- FIREWALL --------
fw = {}
def safe(cmd):
    try:
        return subprocess.check_output(cmd, stderr=subprocess.DEVNULL).decode()
    except:
        return ""

for f in data.get("firewalls", []):
    if f == "ufw":
        fw[f] = safe(["ufw","status","verbose"])
    elif f == "iptables":
        fw[f] = safe(["iptables-save"])
    elif f == "nftables":
        fw[f] = safe(["nft","list","ruleset"])

result["firewalls"] = fw

# -------- FILES --------
files = []
for f in data.get("files", []):
    if not os.path.exists(f):
        files.append({"path": f, "exists": False})
    else:
        st = os.stat(f)
        import pwd, grp
        files.append({
            "path": f,
            "exists": True,
            "owner": pwd.getpwuid(st.st_uid).pw_name,
            "group": grp.getgrgid(st.st_gid).gr_name,
            "mode": oct(st.st_mode & 0o777)
        })

result["files"] = files

# -------- DIRECTORIES --------
dirs = []
EXPECTED_FLAGS = {"nodev", "noexec", "nosuid"}

for d in data.get("directories", []):
    try:
        out = subprocess.check_output(["findmnt","-no","OPTIONS",d], stderr=subprocess.DEVNULL).decode().strip()
        options = out.split(",")
        present = EXPECTED_FLAGS & set(options)
        missing = EXPECTED_FLAGS - set(options)
        dirs.append({
            "path": d,
            "mounted": True,
            "options": options,
            "nodev":   "nodev"   in options,
            "noexec":  "noexec"  in options,
            "nosuid":  "nosuid"  in options,
            "missing_flags": sorted(missing)
        })
    except:
        dirs.append({
            "path": d,
            "mounted": False,
            "options": [],
            "nodev":   False,
            "noexec":  False,
            "nosuid":  False,
            "missing_flags": sorted(EXPECTED_FLAGS)
        })

result["directories"] = dirs
print(json.dumps(result))
EOF
)

# ---------- WRITE JSON ----------
if [[ -z "$OUT" ]]; then
    echo "[!] Failed to generate state JSON"
    exit 1
fi

python3 -c "
import json, os, sys
data = json.loads(sys.argv[1])
json.dump(data, open('$OUTPUT_JSON', 'w'), indent=2)
os.chmod('$OUTPUT_JSON', 0o600)
" "$OUT"

echo "[+] Snapshot JSON generated: $OUTPUT_JSON"