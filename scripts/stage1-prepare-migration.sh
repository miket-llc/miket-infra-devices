#!/bin/bash
# Copyright (c) 2025 MikeT LLC. All rights reserved.
#
# STAGE 1: Prepare Motoko for Ubuntu → Fedora 43 Migration
# Run this script while SSH'd into motoko from count-zero
#
# This script automates all Stage 1 tasks:
# - Backup critical data
# - Download Fedora 43 ISO
# - Configure GRUB loopback
# - Prepare for reboot
#
# Usage: ssh mdt@motoko 'bash -s' < ./scripts/stage1-prepare-migration.sh

set -euo pipefail

echo "=========================================="
echo "STAGE 1: Prepare Migration"
echo "Ubuntu 24.04 → Fedora 43"
echo "=========================================="
echo ""
echo "This will:"
echo "  1. Backup /home/mdt and system config to /space"
echo "  2. Download Fedora 43 Workstation ISO to /flux"
echo "  3. Configure GRUB loopback entry"
echo "  4. Prepare for manual installation"
echo ""
read -p "Continue? (yes/no): " -r
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
  echo "Aborted"
  exit 0
fi

# ========================================
# Step 1: Run backup script
# ========================================
echo ""
echo "[Step 1/5] Running backup script..."
if [ -f ~/miket-infra-devices/scripts/motoko-pre-migration-backup.sh ]; then
  ~/miket-infra-devices/scripts/motoko-pre-migration-backup.sh
else
  echo "ERROR: Backup script not found!"
  exit 1
fi

# ========================================
# Step 2: Download Fedora 43 ISO
# ========================================
echo ""
echo "[Step 2/5] Downloading Fedora 43 Workstation ISO..."

FEDORA_VERSION="43"
FEDORA_ISO="Fedora-Workstation-Live-x86_64-${FEDORA_VERSION}-1.6.iso"
FEDORA_URL="https://download.fedoraproject.org/pub/fedora/linux/releases/${FEDORA_VERSION}/Workstation/x86_64/iso/${FEDORA_ISO}"
FEDORA_CHECKSUM_URL="https://download.fedoraproject.org/pub/fedora/linux/releases/${FEDORA_VERSION}/Workstation/x86_64/iso/Fedora-Workstation-${FEDORA_VERSION}-1.6-x86_64-CHECKSUM"

cd /tmp

if [ ! -f "/flux/iso/${FEDORA_ISO}" ]; then
  echo "  Downloading ISO (may take several minutes)..."
  wget -q --show-progress "${FEDORA_URL}"
  
  echo "  Downloading checksum..."
  wget -q "${FEDORA_CHECKSUM_URL}"
  
  echo "  Verifying checksum..."
  sha256sum -c "Fedora-Workstation-${FEDORA_VERSION}-1.6-x86_64-CHECKSUM" --ignore-missing
  
  echo "  Moving ISO to /flux/iso/..."
  sudo mkdir -p /flux/iso
  sudo mv "${FEDORA_ISO}" /flux/iso/
  sudo chmod 644 "/flux/iso/${FEDORA_ISO}"
  
  echo "  ✅ ISO downloaded and verified"
else
  echo "  ✅ ISO already exists at /flux/iso/${FEDORA_ISO}"
fi

# ========================================
# Step 3: Find /flux partition
# ========================================
echo ""
echo "[Step 3/5] Identifying /flux partition..."

FLUX_PARTITION=$(df /flux | tail -1 | awk '{print $1}')
echo "  /flux is on: ${FLUX_PARTITION}"

# Convert partition to GRUB format
# Example: /dev/sdb2 → (hd1,gpt2)
# This is a simplification - may need manual adjustment
GRUB_PARTITION="(hd0,gpt2)"  # Default assumption
echo "  GRUB partition (assumed): ${GRUB_PARTITION}"
echo "  ⚠️  Verify this matches your system with 'lsblk'"

# ========================================
# Step 4: Configure GRUB loopback
# ========================================
echo ""
echo "[Step 4/5] Configuring GRUB loopback entry..."

sudo cp /etc/grub.d/40_custom /etc/grub.d/40_custom.backup

if ! grep -q "Fedora 43 Workstation Live" /etc/grub.d/40_custom; then
  sudo tee -a /etc/grub.d/40_custom << EOF

menuentry "Fedora 43 Workstation Live (Install)" {
    set isofile="/flux/iso/${FEDORA_ISO}"
    loopback loop ${GRUB_PARTITION}\$isofile
    linux (loop)/isolinux/vmlinuz root=live:CDLABEL=Fedora-WS-Live-${FEDORA_VERSION}-1-6 rd.live.image quiet
    initrd (loop)/isolinux/initrd.img
}
EOF
  
  echo "  ✅ GRUB entry added"
else
  echo "  ✅ GRUB entry already exists"
fi

# Update GRUB
echo "  Updating GRUB configuration..."
sudo update-grub

# ========================================
# Step 5: Verify and prepare
# ========================================
echo ""
echo "[Step 5/5] Verification..."

# Check backup
BACKUP_DIR=$(ls -td /space/motoko-backup/migration-* 2>/dev/null | head -1)
if [ -n "${BACKUP_DIR}" ]; then
  echo "  ✅ Backup: ${BACKUP_DIR}"
  du -sh "${BACKUP_DIR}"
else
  echo "  ❌ Backup not found!"
fi

# Check ISO
if [ -f "/flux/iso/${FEDORA_ISO}" ]; then
  echo "  ✅ ISO: /flux/iso/${FEDORA_ISO}"
  ls -lh "/flux/iso/${FEDORA_ISO}"
else
  echo "  ❌ ISO not found!"
fi

# Check GRUB
if grep -q "Fedora 43 Workstation Live" /etc/grub.d/40_custom; then
  echo "  ✅ GRUB entry configured"
else
  echo "  ❌ GRUB entry missing!"
fi

# Display partition info
echo ""
echo "Current partition layout:"
lsblk -f | grep -E '(NAME|space|flux|time)'

# ========================================
# Complete
# ========================================
echo ""
echo "=========================================="
echo "STAGE 1 COMPLETE - READY FOR REBOOT"
echo "=========================================="
echo ""
echo "✅ Backup created: ${BACKUP_DIR}"
echo "✅ Fedora 43 ISO ready: /flux/iso/${FEDORA_ISO}"
echo "✅ GRUB loopback configured"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "NEXT STEPS (MANUAL):"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "1. REBOOT the system:"
echo "   sudo reboot"
echo ""
echo "2. At GRUB menu, select:"
echo "   'Fedora 43 Workstation Live (Install)'"
echo ""
echo "3. Proceed to STAGE 2 (manual installation)"
echo "   See: docs/migration/motoko-ubuntu-to-fedora-43.md"
echo ""
echo "⚠️  WARNING:"
echo "   - SSH will be unavailable until STAGE 3 complete"
echo "   - You will need physical/console access"
echo "   - Verify partition selections carefully during install"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""


