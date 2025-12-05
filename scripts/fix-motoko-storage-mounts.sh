#!/bin/bash
# Copyright (c) 2025 MikeT LLC. All rights reserved.
#
# fix-motoko-storage-mounts.sh
# Recovery script for motoko storage mounts
#
# This script fixes common mount issues on motoko:
# - Stale mounts from device name drift (USB drive replugged)
# - Multiple mounts on same mountpoint
# - Emergency read-only mounts due to I/O errors
#
# Usage:
#   sudo ./fix-motoko-storage-mounts.sh
#
# Root Cause Context (2025-12-05):
#   USB drives can change device names (e.g., /dev/sdb → /dev/sdd) after
#   reboots or replug events. This causes:
#   1. Stale mounts pointing to non-existent device names
#   2. Multiple mounts on /time and /space
#   3. I/O errors and emergency_ro flags
#   
#   The fix is to unmount all stale mounts and remount using UUID-based
#   fstab entries which are stable across device name changes.

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log() { echo -e "${CYAN}[$(date '+%H:%M:%S')]${NC} $1"; }
success() { echo -e "${GREEN}✓${NC} $1"; }
warn() { echo -e "${YELLOW}⚠${NC} $1"; }
error() { echo -e "${RED}✗${NC} $1"; }

# Must be run as root
if [[ $EUID -ne 0 ]]; then
    error "This script must be run as root (sudo)"
    exit 1
fi

CRITICAL_MOUNTS=("/time" "/space" "/flux")

echo "=========================================="
echo "Motoko Storage Mount Recovery"
echo "=========================================="
echo ""

# Step 1: Stop services that use the mounts
log "Step 1: Stopping Samba to release mount handles..."
if systemctl is-active --quiet smb 2>/dev/null; then
    systemctl stop smb
    success "Samba stopped"
else
    warn "Samba was not running"
fi

# Step 2: Force unmount any stale mounts
log "Step 2: Unmounting stale mounts..."
for mount_point in "${CRITICAL_MOUNTS[@]}"; do
    # Count how many times this mount point appears
    mount_count=$(mount | grep -c "on $mount_point " || true)
    
    if [[ "$mount_count" -gt 0 ]]; then
        log "  $mount_point has $mount_count mount(s)"
        
        # Lazy unmount each instance
        for i in $(seq 1 "$mount_count"); do
            if umount -l "$mount_point" 2>/dev/null; then
                success "  Unmounted $mount_point (instance $i)"
            else
                warn "  Could not unmount $mount_point (instance $i)"
            fi
        done
    else
        success "  $mount_point was not mounted"
    fi
done

# Step 3: Wait for unmounts to complete
log "Step 3: Waiting for unmounts to settle..."
sleep 2

# Step 4: Verify no mounts remain
log "Step 4: Verifying mounts are cleared..."
remaining=$(mount | grep -E "on /(time|space|flux) " || true)
if [[ -n "$remaining" ]]; then
    warn "Some mounts still present:"
    echo "$remaining" | sed 's/^/    /'
else
    success "All critical mounts cleared"
fi

# Step 5: Remount from fstab (using UUIDs)
log "Step 5: Remounting from fstab..."
echo ""
echo "Expected fstab entries (UUID-based):"
grep -E "/(time|space|flux)" /etc/fstab | sed 's/^/    /' || warn "No entries found in fstab!"
echo ""

for mount_point in "${CRITICAL_MOUNTS[@]}"; do
    if mount "$mount_point" 2>/dev/null; then
        success "Mounted $mount_point"
    else
        error "Failed to mount $mount_point"
    fi
done

# Step 6: Verify mounts are accessible
log "Step 6: Verifying mount accessibility..."
all_ok=true
for mount_point in "${CRITICAL_MOUNTS[@]}"; do
    if ls "$mount_point" >/dev/null 2>&1; then
        device=$(findmnt -n -o SOURCE "$mount_point" 2>/dev/null || echo "unknown")
        success "$mount_point accessible (device: $device)"
    else
        error "$mount_point is NOT accessible!"
        all_ok=false
    fi
done

# Step 7: Start Samba
log "Step 7: Starting Samba..."
if systemctl start smb; then
    success "Samba started"
else
    error "Failed to start Samba"
    all_ok=false
fi

# Summary
echo ""
echo "=========================================="
echo "Recovery Summary"
echo "=========================================="

echo ""
echo "Current mount status:"
mount | grep -E "/(time|space|flux)" | sed 's/^/    /' || echo "    (no mounts found)"

echo ""
if $all_ok; then
    success "Recovery completed successfully!"
    echo ""
    echo "Next steps:"
    echo "  1. Verify Time Machine can connect from count-zero"
    echo "  2. Check Samba connections: sudo smbstatus"
    echo "  3. Monitor for future issues: ./check-motoko-storage-health.sh"
else
    error "Recovery had issues. Manual intervention may be required."
    echo ""
    echo "Troubleshooting:"
    echo "  1. Check dmesg for disk errors: sudo dmesg | grep -i error | tail -30"
    echo "  2. Check disk health: sudo smartctl -a /dev/sdX"
    echo "  3. Check fstab UUIDs match actual disks: blkid"
fi

