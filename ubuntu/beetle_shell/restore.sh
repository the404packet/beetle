#!/usr/bin/env bash

SNAPSHOT_FILE=""
BASE_DIR="/var/lib/beetle"
META_FILE="$BASE_DIR/.snapshot_meta"
OBJECT_DIR="$BASE_DIR/.objects"
MANIFEST_DIR="$BASE_DIR/.manifests"
RESTORE_TMP="$BASE_DIR/.restore_tmp"
ETC_BEETLE="/etc/beetle"

# ---------- ROOT CHECK ----------
if [[ "$EUID" -ne 0 ]]; then
    echo "[!] Must be run as root"
    exit 1
fi

# ---------- ARGS ----------
while [[ $# -gt 0 ]]; do
    case "$1" in
        --snapshot) SNAPSHOT_FILE="$2"; shift 2 ;;
        *) SNAPSHOT_FILE="$1"; shift ;;
    esac
done

# ---------- RESOLVE SNAPSHOT ----------
if [[ -z "$SNAPSHOT_FILE" || "$SNAPSHOT_FILE" == "latest" ]]; then
    MATCH=$(tail -n1 "$META_FILE")
    if [[ -z "$MATCH" ]]; then
        echo "[!] No snapshots found"
        exit 1
    fi
    echo "[*] Restoring latest snapshot"
else
    MATCH=$(grep -E "^${SNAPSHOT_FILE}\|" "$META_FILE")
    [[ -z "$MATCH" ]] && MATCH=$(grep -E "\|${SNAPSHOT_FILE}\|" "$META_FILE")

    if [[ -z "$MATCH" ]]; then
        echo "[!] No snapshot found for: $SNAPSHOT_FILE"
        exit 1
    fi
fi

SNAP_ID=$(echo "$MATCH"    | cut -d'|' -f1)
SNAP_LABEL=$(echo "$MATCH" | cut -d'|' -f2)
SNAP_TYPE=$(echo "$MATCH"  | cut -d'|' -f4)

if [[ "$SNAP_TYPE" == "beetle" ]]; then
    SNAP_LINK="$BASE_DIR/beetle_snapshots/$SNAP_LABEL"
else
    SNAP_LINK="$BASE_DIR/user_snapshots/$SNAP_LABEL"
fi

if [[ ! -L "$SNAP_LINK" ]]; then
    echo "[!] Snapshot link not found: $SNAP_LINK"
    exit 1
fi

# Resolve manifest from symlink
MANIFEST_FILE=$(readlink -f "$SNAP_LINK")
if [[ ! -f "$MANIFEST_FILE" ]]; then
    echo "[!] Snapshot manifest not found: $MANIFEST_FILE"
    exit 1
fi

echo "[*] Snapshot : $SNAP_LABEL"
echo "[*] Manifest : $MANIFEST_FILE"

# ---------- PRE-RESTORE SNAPSHOT ----------
echo "[*] Capturing pre-restore safety snapshot..."
SNAP_RESPONSE=$(beetle snapshot capture main 2>&1)

if echo "$SNAP_RESPONSE" | grep -q "\[+\] Snapshot created"; then
    echo "[+] Safety snapshot captured"
else
    echo "[!] Safety snapshot failed — aborting"
    echo "$SNAP_RESPONSE"
    exit 1
fi

# ---------- RESTORE /etc/beetle FILES FROM OBJECT STORE ----------
trap 'rm -rf "$RESTORE_TMP"' EXIT
rm -rf "$RESTORE_TMP"
mkdir -p "$RESTORE_TMP"

echo "[*] Restoring /etc/beetle files from object store..."

python3 - <<PYEOF
import json, os, shutil, sys

manifest = json.load(open("$MANIFEST_FILE"))
object_dir = "$OBJECT_DIR"
source_dir = "$ETC_BEETLE"
restore_tmp = "$RESTORE_TMP"

for rel_path, file_hash in manifest.get("files", {}).items():
    if rel_path == "__state__":
        continue
    prefix = file_hash[:2]
    obj_path = os.path.join(object_dir, prefix, file_hash)
    if not os.path.exists(obj_path):
        print(f"    [!] Missing object for {rel_path} ({file_hash})")
        continue
    dest = os.path.join(source_dir, rel_path)
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    shutil.copy2(obj_path, dest)
    print(f"    [+] Restored: {rel_path}")

# Extract state.json to RESTORE_TMP for use below
state_hash = manifest.get("files", {}).get("__state__")
if state_hash:
    prefix = state_hash[:2]
    obj_path = os.path.join(object_dir, prefix, state_hash)
    if os.path.exists(obj_path):
        shutil.copy2(obj_path, os.path.join(restore_tmp, "state.json"))
        print("    [+] Loaded state.json from object store")
    else:
        print("    [!] state.json object missing")
PYEOF

# ---------- LOAD STATE ----------
STATE_FILE="$RESTORE_TMP/state.json"
if [[ ! -f "$STATE_FILE" ]]; then
    echo "[!] state.json not found in object store for this snapshot"
    exit 1
fi

python3 - <<EOF
import json, subprocess, os, sys

state = json.load(open("$STATE_FILE"))

# -------- PACKAGES --------
for pkg in state.get("packages", []):
    name = pkg["name"]
    installed = pkg["installed"]

    if installed:
        result = subprocess.run(["dpkg","-s",name], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        if result.returncode != 0:
            print(f"    [*] Installing {name}...")
            subprocess.run(
                ["apt-get","install","-y",name],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL
            )
            print(f"    [+] Installed: {name}")
    else:
        result = subprocess.run(["dpkg","-s",name], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        if result.returncode == 0:
            print(f"    [*] Removing {name}...")
            subprocess.run(
                ["apt-get","remove","-y",name],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL
            )
            print(f"    [+] Removed: {name}")

    for svc in pkg.get("services", []):
        sname = svc["name"]

        current_enabled = subprocess.run(
            ["systemctl","is-enabled",sname],
            capture_output=True
        ).stdout.decode().strip()

        if svc["enabled"] and current_enabled != "enabled":
            subprocess.run(["systemctl","enable",sname], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            print(f"    [+] Enabled: {sname}")
        elif not svc["enabled"] and current_enabled == "enabled":
            subprocess.run(["systemctl","disable",sname], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            print(f"    [+] Disabled: {sname}")

        current_active = subprocess.run(
            ["systemctl","is-active",sname],
            capture_output=True
        ).stdout.decode().strip()

        if svc["active"] and current_active != "active":
            subprocess.run(["systemctl","start",sname], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            print(f"    [+] Started: {sname}")
        elif not svc["active"] and current_active == "active":
            subprocess.run(["systemctl","stop",sname], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            print(f"    [+] Stopped: {sname}")

# -------- FILES --------
for f in state.get("files", []):
    path = f["path"]
    if not f.get("exists") or not os.path.exists(path):
        continue

    owner = f.get("owner")
    group = f.get("group")
    mode  = f.get("mode")

    if owner and group:
        subprocess.run(["chown", f"{owner}:{group}", path], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        print(f"    [+] chown {owner}:{group} {path}")

    if mode:
        os.chmod(path, int(mode, 8))
        print(f"    [+] chmod {mode} {path}")

# -------- FIREWALL --------
fw = state.get("firewalls", {})

if "ufw" in fw and fw["ufw"]:
    print("    [*] Restoring ufw rules...")
    subprocess.run(["ufw","--force","reset"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    for line in fw["ufw"].splitlines():
        line = line.strip()
        if not line or line.startswith("#") or line.startswith("Status"):
            continue
        subprocess.run(["ufw"] + line.split(), stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    subprocess.run(["ufw","--force","enable"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    print("    [+] ufw restored")

if "iptables" in fw and fw["iptables"]:
    print("    [*] Restoring iptables rules...")
    proc = subprocess.Popen(
        ["iptables-restore"],
        stdin=subprocess.PIPE,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL
    )
    proc.communicate(input=fw["iptables"].encode())
    print("    [+] iptables restored")

if "nftables" in fw and fw["nftables"]:
    print("    [*] Restoring nftables rules...")
    proc = subprocess.Popen(
        ["nft","-f","-"],
        stdin=subprocess.PIPE,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL
    )
    proc.communicate(input=fw["nftables"].encode())
    print("    [+] nftables restored")

# -------- DIRECTORIES --------
for d in state.get("directories", []):
    path = d["path"]
    if not d.get("mounted"):
        continue

    missing = d.get("missing_flags", [])
    if not missing:
        continue

    with open("/etc/fstab", "r") as fstab:
        lines = fstab.readlines()

    new_lines = []
    updated = False
    for line in lines:
        if line.strip().startswith("#") or len(line.strip().split()) < 4:
            new_lines.append(line)
            continue
        parts = line.split()
        if parts[1] == path:
            opts = parts[3].split(",")
            for flag in missing:
                if flag not in opts:
                    opts.append(flag)
            parts[3] = ",".join(opts)
            new_lines.append("\t".join(parts) + "\n")
            updated = True
            print(f"    [+] fstab updated for {path}: added {missing}")
        else:
            new_lines.append(line)

    if updated:
        with open("/etc/fstab", "w") as fstab:
            fstab.writelines(new_lines)
        subprocess.run(["mount","-o","remount",path], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        print(f"    [+] Remounted: {path}")

    # -------- USERS --------
import pwd, grp, spwd

for u in state.get("users", []):
    name  = u["name"]
    uid   = u["uid"]
    gid   = u["gid"]
    home  = u["home"]
    shell = u["shell"]

    try:
        pwd.getpwnam(name)
    except KeyError:
        subprocess.run([
            "useradd", "-u", str(uid), "-g", str(gid),
            "-d", home, "-s", shell, name
        ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        print(f"    [+] Created user: {name}")
    else:
        subprocess.run([
            "usermod", "-u", str(uid), "-g", str(gid),
            "-d", home, "-s", shell, name
        ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        print(f"    [+] Updated user: {name}")

# -------- GROUPS --------
for g in state.get("groups", []):
    name    = g["name"]
    gid     = g["gid"]
    members = g.get("members", [])

    try:
        grp.getgrnam(name)
    except KeyError:
        subprocess.run([
            "groupadd", "-g", str(gid), name
        ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        print(f"    [+] Created group: {name}")
    else:
        subprocess.run([
            "groupmod", "-g", str(gid), name
        ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        print(f"    [+] Updated group: {name}")

    for member in members:
        subprocess.run([
            "usermod", "-aG", name, member
        ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

print("\n[+] Restore complete")
EOF