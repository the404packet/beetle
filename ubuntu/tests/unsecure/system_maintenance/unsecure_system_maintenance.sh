#!/usr/bin/env bash

# ==============================================================================
# Comprehensive Unsecure Script for System Maintenance Module
# Unsecures file permissions, backup permissions, and account integrity checks
# ==============================================================================

echo "[Unsecure] Unsecuring System Maintenance settings & permissions..."

# ------------------------------------------------------------------------------
# 1. File Permissions & Backup Permissions (Set overly permissive modes: 666 / 777)
# ------------------------------------------------------------------------------

# /etc/passwd and backup
[ -f /etc/passwd ] && chmod 666 /etc/passwd 2>/dev/null || true
[ -f /etc/passwd- ] && chmod 666 /etc/passwd- 2>/dev/null || true

# /etc/shadow and backup
[ -f /etc/shadow ] && chmod 644 /etc/shadow 2>/dev/null || true
[ -f /etc/shadow- ] && chmod 644 /etc/shadow- 2>/dev/null || true

# /etc/group and backup
[ -f /etc/group ] && chmod 666 /etc/group 2>/dev/null || true
[ -f /etc/group- ] && chmod 666 /etc/group- 2>/dev/null || true

# /etc/gshadow and backup
[ -f /etc/gshadow ] && chmod 644 /etc/gshadow 2>/dev/null || true
[ -f /etc/gshadow- ] && chmod 644 /etc/gshadow- 2>/dev/null || true

# /etc/shells
[ -f /etc/shells ] && chmod 777 /etc/shells 2>/dev/null || true

# /etc/security/opasswd and opasswd.old
if [ -f /etc/security/opasswd ]; then
    chmod 666 /etc/security/opasswd 2>/dev/null || true
else
    touch /etc/security/opasswd && chmod 666 /etc/security/opasswd
fi

if [ -f /etc/security/opasswd.old ]; then
    chmod 666 /etc/security/opasswd.old 2>/dev/null || true
else
    touch /etc/security/opasswd.old && chmod 666 /etc/security/opasswd.old
fi

# ------------------------------------------------------------------------------
# 2. Local User & Group Settings (Inject unsecure user/group anomalies)
# ------------------------------------------------------------------------------

# A. Non-shadowed password user (password field not set to 'x')
if ! grep -q "^unshadowed_user:" /etc/passwd; then
    echo "unshadowed_user:plainpass:9990:9990:Unshadowed User:/nonexistent:/bin/bash" >> /etc/passwd
fi

# B. Passwd GID that does not exist in /etc/group
if ! grep -q "^missing_gid_user:" /etc/passwd; then
    echo "missing_gid_user:x:9991:8888:Missing GID User:/nonexistent:/bin/bash" >> /etc/passwd
fi

# C. Duplicate GID and Duplicate Group Name in /etc/group
if ! grep -q "^dup_group1:" /etc/group; then
    echo "dup_group1:x:9992:" >> /etc/group
    echo "dup_group1:x:9992:" >> /etc/group
fi

# D. Duplicate Username in /etc/passwd
if ! grep -q "^dup_user1:" /etc/passwd; then
    echo "dup_user1:x:9993:9993:Dup User 1:/nonexistent:/bin/bash" >> /etc/passwd
    echo "dup_user1:x:9994:9994:Dup User 2:/nonexistent:/bin/bash" >> /etc/passwd
fi

# E. Duplicate UID in /etc/passwd
if ! grep -q "^dup_uid1:" /etc/passwd; then
    echo "dup_uid1:x:9995:9995:Dup UID 1:/nonexistent:/bin/bash" >> /etc/passwd
    echo "dup_uid2:x:9995:9995:Dup UID 2:/nonexistent:/bin/bash" >> /etc/passwd
fi

# F. Add user to shadow group to trigger shadow_group_isempty check failure
if grep -q "^shadow:" /etc/group; then
    sed -i 's/^shadow:x:\([0-9]*\):.*/shadow:x:\1:unshadowed_user/' /etc/group
fi

# G. Empty password field in /etc/shadow
if ! grep -q "^empty_pass_user:" /etc/passwd; then
    echo "empty_pass_user:x:9996:9996:Empty Pass User:/nonexistent:/bin/bash" >> /etc/passwd
    echo "empty_pass_user::19000:0:99999:7:::" >> /etc/shadow
fi

# H. Create an unapproved/non-package SUID binary to trigger SUID audit failure
touch /usr/bin/unsecure_suid_test
chmod 4755 /usr/bin/unsecure_suid_test

