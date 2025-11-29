#!/bin/bash
# Copyright (c) 2025 MikeT LLC. All rights reserved.
#
# Pre-Migration Backup Script for Motoko
# Creates backups of critical configuration and data before Ubuntu → Fedora migration
#
# Usage: ./motoko-pre-migration-backup.sh [backup-dir]
# Default backup location: /flux/backups/migration-$(date +%Y%m%d-%H%M%S)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_BASE="${1:-/flux/backups}"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_DIR="${BACKUP_BASE}/migration-${TIMESTAMP}"

echo "=========================================="
echo "Motoko Pre-Migration Backup"
echo "=========================================="
echo "Backup directory: ${BACKUP_DIR}"
echo ""

# Create backup directory structure
mkdir -p "${BACKUP_DIR}"/{home,etc,services,docker,ansible,logs,system}

echo "[1/8] Backing up user home directory..."
tar -czf "${BACKUP_DIR}/home/mdt-home.tar.gz" \
  -C /home mdt \
  --exclude='mdt/.cache' \
  --exclude='mdt/.local/share/Trash' \
  --exclude='mdt/.npm' \
  --exclude='mdt/.mozilla/firefox/*/cache2' \
  2>/dev/null || echo "Warning: Some files may have been excluded"

echo "[2/8] Backing up /etc (system configuration)..."
sudo tar -czf "${BACKUP_DIR}/etc/etc.tar.gz" \
  -C / etc \
  --exclude='etc/apt' \
  --exclude='etc/dpkg' \
  2>/dev/null

echo "[3/8] Backing up service configurations (for reference only)..."
# NOTE: These are backed up for REFERENCE only, NOT for direct restoration
# Fedora will use Ansible-managed templates instead

# Samba (save for share config reference)
if [ -d /etc/samba ]; then
  sudo cp -r /etc/samba "${BACKUP_DIR}/services/samba"
fi

# NoMachine (save for port/access config reference)
if [ -d /usr/NX/etc ]; then
  sudo cp -r /usr/NX/etc "${BACKUP_DIR}/services/nomachine"
fi

# fail2ban (save for jail config reference)
if [ -d /etc/fail2ban ]; then
  sudo cp -r /etc/fail2ban "${BACKUP_DIR}/services/fail2ban"
fi

# postfix (save for relay config reference)
if [ -d /etc/postfix ]; then
  sudo cp -r /etc/postfix "${BACKUP_DIR}/services/postfix"
fi

echo "[4/8] Backing up Docker configurations..."
# Docker Compose files
if [ -d ~/miket-infra-devices ]; then
  find ~/miket-infra-devices -name "docker-compose*.yml" -o -name "docker-compose*.yaml" | \
    xargs -I {} cp --parents {} "${BACKUP_DIR}/docker/" 2>/dev/null || true
fi

# Docker volumes (list only, not full backup - too large)
docker volume ls > "${BACKUP_DIR}/docker/volumes-list.txt" 2>/dev/null || true

echo "[5/8] Backing up Ansible repository..."
if [ -d ~/miket-infra-devices ]; then
  tar -czf "${BACKUP_DIR}/ansible/miket-infra-devices.tar.gz" \
    -C ~ miket-infra-devices \
    --exclude='miket-infra-devices/.git/objects' \
    --exclude='miket-infra-devices/.git/index' \
    2>/dev/null || echo "Warning: Git objects excluded (use git clone for full backup)"
fi

echo "[6/8] Backing up system information..."
# Partition layout
lsblk > "${BACKUP_DIR}/system/lsblk.txt"
df -h > "${BACKUP_DIR}/system/df-h.txt"
sudo fdisk -l > "${BACKUP_DIR}/system/fdisk-l.txt" 2>/dev/null || true
sudo blkid > "${BACKUP_DIR}/system/blkid.txt"

# Mounts
cat /etc/fstab > "${BACKUP_DIR}/system/fstab.txt"

# Services
systemctl list-units --type=service --state=running > "${BACKUP_DIR}/system/services-running.txt"
systemctl list-units --type=service --all > "${BACKUP_DIR}/system/services-all.txt"

# Network
ip addr show > "${BACKUP_DIR}/system/ip-addr.txt"
ip route show > "${BACKUP_DIR}/system/ip-route.txt"

# Tailscale
tailscale status > "${BACKUP_DIR}/system/tailscale-status.txt" 2>/dev/null || true

echo "[7/8] Backing up package lists..."
# Ubuntu package list
dpkg -l > "${BACKUP_DIR}/system/installed-packages.txt" 2>/dev/null || true
apt list --installed > "${BACKUP_DIR}/system/apt-installed.txt" 2>/dev/null || true

echo "[8/8] Creating backup manifest..."
cat > "${BACKUP_DIR}/MANIFEST.txt" <<EOF
Motoko Pre-Migration Backup (Ubuntu → Fedora 43)
=================================================
Date: $(date)
Hostname: $(hostname)
OS: $(lsb_release -d | cut -f2)
Kernel: $(uname -r)

Backup Contents:
- /home/mdt: User home directory (PARTIAL restore)
- /etc: System configuration (REFERENCE ONLY, not for direct restore)
- Service configs: Samba, NoMachine, fail2ban, postfix (REFERENCE ONLY)
- Docker: Compose files and volume list
- Ansible: miket-infra-devices repository
- System info: Partitions, mounts, services, network

IMPORTANT NOTES:
- Do NOT blindly restore /etc - Fedora has different structure
- Service configs are for REFERENCE only - use Ansible templates
- /home/mdt will be cleaned of desktop configs (see cleanup script)
- Only SSH keys, code, docs, and app data should be preserved

Restore Strategy:
1. Fresh Fedora 43 installation with custom partitioning
2. Run cleanup-ubuntu-config.sh to remove old desktop configs
3. Use Ansible to configure all services (fedora-base.yml)
4. Reference backed-up configs only if needed for Ansible templates

See: docs/migration/motoko-ubuntu-to-fedora-43.md

Backup Location: ${BACKUP_DIR}
EOF

# Set permissions
sudo chown -R "${USER}:${USER}" "${BACKUP_DIR}"
chmod -R u+rw "${BACKUP_DIR}"

echo ""
echo "=========================================="
echo "Backup Complete!"
echo "=========================================="
echo "Backup location: ${BACKUP_DIR}"
echo ""
echo "Backup size:"
du -sh "${BACKUP_DIR}"
echo ""
echo "Next steps:"
echo "1. Review backup contents"
echo "2. Test backup restoration (optional)"
echo "3. Proceed with migration (see docs/migration/ubuntu-to-fedora-migration.md)"
echo ""

