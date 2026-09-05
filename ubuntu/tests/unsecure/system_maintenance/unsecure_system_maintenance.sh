#!/usr/bin/env bash

# ==============================================================================
# Unsecure System Maintenance Module Settings (File permissions, passwd/shadow)
# ==============================================================================

echo "[Unsecure] Messing up system file permissions..."

# 1. Unsecure permissions on sensitive system credential files
# Change permissions of /etc/shadow to overly permissive mode (e.g. 644)
if [ -f /etc/shadow ]; then
    chmod 644 /etc/shadow 2>/dev/null || true
fi

# Change permissions of /etc/gshadow
if [ -f /etc/gshadow ]; then
    chmod 644 /etc/gshadow 2>/dev/null || true
fi

# Change permissions of /etc/passwd-
if [ -f /etc/passwd- ]; then
    chmod 666 /etc/passwd- 2>/dev/null || true
fi

# Change permissions of /etc/shells
if [ -f /etc/shells ]; then
    chmod 777 /etc/shells 2>/dev/null || true
fi
