#!/bin/bash
# Copyright (c) 2025 MikeT LLC. All rights reserved.

# =============================================================================
# Akira Storage Setup Script
# =============================================================================
# 
# Purpose: Format and configure akira's storage infrastructure
#   - /space (18TB sda)   → btrfs (SoR, compressed)
#   - /flux  (4TB nvme1n1) → ext4  (runtime, fast)
#   - /time  (4TB nvme2n1) → ext4  (backups)
#
# WARNING: This will DESTROY ALL DATA on sda, nvme1n1, nvme2n1
#
# =============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Drives
SPACE_DEV="/dev/sda"
FLUX_DEV="/dev/nvme1n1"
TIME_DEV="/dev/nvme2n1"

# Mount points
SPACE_MOUNT="/space"
FLUX_MOUNT="/flux"
TIME_MOUNT="/time"

# =============================================================================
# Helper Functions
# =============================================================================

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

confirm() {
    local prompt="$1"
    read -p "$prompt [yes/NO]: " response
    if [[ "$response" != "yes" ]]; then
        log_error "Operation cancelled by user"
        exit 1
    fi
}

check_device_exists() {
    local device="$1"
    if [[ ! -b "$device" ]]; then
        log_error "Device $device does not exist!"
        exit 1
    fi
}

unmount_if_mounted() {
    local device="$1"
    if mount | grep -q "^${device}"; then
        log_warn "Device $device is currently mounted, unmounting..."
        sudo umount -f "${device}"* 2>/dev/null || true
    fi
}

# =============================================================================
# Pre-flight Checks
# =============================================================================

log_info "Starting Akira Storage Setup"
log_info "============================="

# Check if running as root or with sudo
if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run as root or with sudo"
    exit 1
fi

# Verify devices exist
log_info "Verifying devices..."
check_device_exists "$SPACE_DEV"
check_device_exists "$FLUX_DEV"
check_device_exists "$TIME_DEV"

# Display current state
log_info ""
log_info "Current device information:"
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT "$SPACE_DEV" "$FLUX_DEV" "$TIME_DEV" 2>/dev/null || true

# Final confirmation
log_warn ""
log_warn "⚠️  WARNING: This will DESTROY ALL DATA on the following devices:"
log_warn "   - $SPACE_DEV (18TB) → /space (btrfs, compressed)"
log_warn "   - $FLUX_DEV  (4TB)  → /flux  (ext4)"
log_warn "   - $TIME_DEV  (4TB)  → /time  (ext4)"
log_warn ""
confirm "Are you absolutely sure you want to continue?"

# =============================================================================
# Stage 1: Unmount and Wipe Devices
# =============================================================================

log_info ""
log_info "Stage 1: Unmounting and wiping devices..."

unmount_if_mounted "$SPACE_DEV"
unmount_if_mounted "$FLUX_DEV"
unmount_if_mounted "$TIME_DEV"

log_info "Wiping partition tables..."
sudo wipefs -a "$SPACE_DEV"
sudo wipefs -a "$FLUX_DEV"
sudo wipefs -a "$TIME_DEV"

log_info "Creating new GPT partition tables..."
sudo parted -s "$SPACE_DEV" mklabel gpt
sudo parted -s "$FLUX_DEV" mklabel gpt
sudo parted -s "$TIME_DEV" mklabel gpt

log_info "Creating single partition on each device..."
sudo parted -s "$SPACE_DEV" mkpart primary 0% 100%
sudo parted -s "$FLUX_DEV" mkpart primary 0% 100%
sudo parted -s "$TIME_DEV" mkpart primary 0% 100%

# Wait for kernel to recognize new partitions
sleep 2

# =============================================================================
# Stage 2: Format Filesystems
# =============================================================================

log_info ""
log_info "Stage 2: Formatting filesystems..."

# Determine partition naming (SATA uses 1, NVMe uses p1)
if [[ "$SPACE_DEV" =~ nvme ]]; then
    SPACE_PART="${SPACE_DEV}p1"
else
    SPACE_PART="${SPACE_DEV}1"
fi

if [[ "$FLUX_DEV" =~ nvme ]]; then
    FLUX_PART="${FLUX_DEV}p1"
else
    FLUX_PART="${FLUX_DEV}1"
fi

if [[ "$TIME_DEV" =~ nvme ]]; then
    TIME_PART="${TIME_DEV}p1"
else
    TIME_PART="${TIME_DEV}1"
fi

# /space → btrfs with compression
log_info "Formatting ${SPACE_PART} as btrfs (compressed, SoR)..."
sudo mkfs.btrfs -f -L "space" "${SPACE_PART}"

# /flux → ext4
log_info "Formatting ${FLUX_PART} as ext4 (runtime)..."
sudo mkfs.ext4 -F -L "flux" "${FLUX_PART}"

# /time → ext4
log_info "Formatting ${TIME_PART} as ext4 (backups)..."
sudo mkfs.ext4 -F -L "time" "${TIME_PART}"

# =============================================================================
# Stage 3: Create Mount Points
# =============================================================================

log_info ""
log_info "Stage 3: Creating mount points..."

sudo mkdir -p "$SPACE_MOUNT"
sudo mkdir -p "$FLUX_MOUNT"
sudo mkdir -p "$TIME_MOUNT"

# =============================================================================
# Stage 4: Mount Filesystems
# =============================================================================

log_info ""
log_info "Stage 4: Mounting filesystems..."

sudo mount -o compress=zstd:3,noatime "${SPACE_PART}" "$SPACE_MOUNT"
sudo mount -o noatime,discard "${FLUX_PART}" "$FLUX_MOUNT"
sudo mount -o noatime,discard "${TIME_PART}" "$TIME_MOUNT"

# =============================================================================
# Stage 5: Update /etc/fstab
# =============================================================================

log_info ""
log_info "Stage 5: Updating /etc/fstab..."

# Get UUIDs
SPACE_UUID=$(sudo blkid -s UUID -o value "${SPACE_PART}")
FLUX_UUID=$(sudo blkid -s UUID -o value "${FLUX_PART}")
TIME_UUID=$(sudo blkid -s UUID -o value "${TIME_PART}")

# Backup existing fstab
sudo cp /etc/fstab /etc/fstab.backup.$(date +%Y%m%d_%H%M%S)

# Add PHC mounts to fstab
cat <<EOF | sudo tee -a /etc/fstab

# PHC Storage Infrastructure (Flux/Space/Time)
# Added by akira-storage-setup.sh on $(date)
UUID=$SPACE_UUID  $SPACE_MOUNT  btrfs  compress=zstd:3,noatime  0  2
UUID=$FLUX_UUID   $FLUX_MOUNT   ext4   noatime,discard          0  2
UUID=$TIME_UUID   $TIME_MOUNT   ext4   noatime,discard          0  2
EOF

log_info "fstab updated with UUIDs for persistent mounts"

# =============================================================================
# Stage 6: Create PHC Directory Structure
# =============================================================================

log_info ""
log_info "Stage 6: Creating PHC directory structure..."

# /space structure (System of Record)
# Keep minimal - directories will be created as needed
log_info "Keeping /space minimal (no pre-created directory structure)..."

# /flux structure (runtime surface)
log_info "Creating /flux directory structure..."
sudo mkdir -p "$FLUX_MOUNT"/apps
sudo mkdir -p "$FLUX_MOUNT"/containers
sudo mkdir -p "$FLUX_MOUNT"/models
sudo mkdir -p "$FLUX_MOUNT"/notebooks
sudo mkdir -p "$FLUX_MOUNT"/projects
sudo mkdir -p "$FLUX_MOUNT"/runtime
sudo mkdir -p "$FLUX_MOUNT"/tmp
sudo mkdir -p "$FLUX_MOUNT"/runtime/secrets
sudo mkdir -p "$FLUX_MOUNT"/containers/engine/podman
sudo mkdir -p "$FLUX_MOUNT"/models/huggingface
sudo mkdir -p "$FLUX_MOUNT"/models/torch

# /time structure (backups)
log_info "Creating /time directory structure..."
sudo mkdir -p "$TIME_MOUNT"/backups
sudo mkdir -p "$TIME_MOUNT"/snapshots
sudo mkdir -p "$TIME_MOUNT"/restic

# =============================================================================
# Stage 7: Set Ownership and Permissions
# =============================================================================

log_info ""
log_info "Stage 7: Setting ownership and permissions..."

# /space owned by mdt (for automation), readable by all
sudo chown -R mdt:mdt "$SPACE_MOUNT"
sudo chmod 755 "$SPACE_MOUNT"

# /flux owned by mdt, runtime secrets restricted
sudo chown -R mdt:mdt "$FLUX_MOUNT"
sudo chmod 755 "$FLUX_MOUNT"
sudo chmod 700 "$FLUX_MOUNT/runtime/secrets"

# /time owned by mdt (for backups)
sudo chown -R mdt:mdt "$TIME_MOUNT"
sudo chmod 755 "$TIME_MOUNT"

# =============================================================================
# Stage 8: Verification
# =============================================================================

log_info ""
log_info "Stage 8: Verifying setup..."

log_info ""
log_info "Mount status:"
df -h | grep -E 'Filesystem|/space|/flux|/time'

log_info ""
log_info "fstab entries:"
grep -E '/space|/flux|/time' /etc/fstab

log_info ""
log_info "Directory structure:"
tree -L 2 -d /space /flux /time 2>/dev/null || ls -la /space /flux /time

# =============================================================================
# Complete
# =============================================================================

log_info ""
log_info "============================="
log_info "✅ Akira Storage Setup Complete!"
log_info "============================="
log_info ""
log_info "Summary:"
log_info "  /space → btrfs (compressed, SoR)      - UUID: $SPACE_UUID"
log_info "  /flux  → ext4  (runtime, fast)        - UUID: $FLUX_UUID"
log_info "  /time  → ext4  (backups)               - UUID: $TIME_UUID"
log_info ""
log_info "Next steps:"
log_info "  1. Verify mounts: df -h"
log_info "  2. Test write access: touch /space/test.txt /flux/test.txt /time/test.txt"
log_info "  3. Configure Podman graphroot: /flux/containers/engine/podman"
log_info "  4. Update host_vars/akira.yml with local mount paths"
log_info ""
log_info "Backup of original fstab saved to: /etc/fstab.backup.*"

