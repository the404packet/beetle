#!/usr/bin/env bash

SNAPSHOT_FILE=""
BASE_DIR="/var/lib/beetle"
META_FILE="$BASE_DIR/.snapshot_meta"
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
    [[ -z "$MATCH" ]] && MATCH=$(grep -E "\|${SNAPSHOT_FILE}\.tar\.gz\|" "$META_FILE")

    if [[ -z "$MATCH" ]]; then
        echo "[!] No snapshot found for: $SNAPSHOT_FILE"
        exit 1
    fi
fi

SNAP_NAME=$(echo "$MATCH" | cut -d'|' -f2)
SNAP_TYPE=$(echo "$MATCH" | cut -d'|' -f4)

if [[ "$SNAP_TYPE" == "beetle" ]]; then
    SNAP_LINK="$BASE_DIR/beetle_snapshots/$SNAP_NAME"
else
    SNAP_LINK="$BASE_DIR/user_snapshots/$SNAP_NAME"
fi

if [[ ! -e "$SNAP_LINK" ]]; then
    echo "[!] Snapshot file not found: $SNAP_LINK"
    exit 1
fi

echo "[*] Snapshot: $SNAP_NAME"

# ---------- PRE-RESTORE SNAPSHOT ----------
echo -e "${CYAN}Capturing pre-harden snapshot...${RESET}"

SNAP_RESPONSE=$(beetle snapshot capture main 2>&1)

if echo "$SNAP_RESPONSE" | grep -q "\[+\] Snapshot created"; then
    echo -e "${GREEN}Snapshot captured${RESET}\n"
else
    echo -e "${RED}Snapshot failed — aborting${RESET}"
    echo "$SNAP_RESPONSE"
    unload_all
    exit 1
fi

# ---------- EXTRACT ----------
trap 'rm -rf "$RESTORE_TMP"' EXIT
rm -rf "$RESTORE_TMP"
mkdir -p "$RESTORE_TMP"

tar -xzf "$SNAP_LINK" -C "$RESTORE_TMP" || {
    echo "[!] Failed to extract snapshot"
    exit 1
}

# ---------- RESTORE /etc/beetle FILES ----------
echo "[*] Restoring /etc/beetle files..."
for f in "$RESTORE_TMP"/*.json "$RESTORE_TMP"/*.conf; do
    [[ -e "$f" ]] || continue
    cp "$f" "$ETC_BEETLE/$(basename "$f")"
    echo "    [+] Restored: $(basename "$f")"
done

# ---------- LOAD STATE ----------
STATE_FILE="$RESTORE_TMP/state.json"
if [[ ! -f "$STATE_FILE" ]]; then
    echo "[!] state.json not found in snapshot"
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