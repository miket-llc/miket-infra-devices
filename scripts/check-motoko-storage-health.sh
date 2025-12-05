#!/bin/bash
# Copyright (c) 2025 MikeT LLC. All rights reserved.
#
# check-motoko-storage-health.sh
# Health check for critical storage mounts on motoko
# 
# This script verifies that /space, /time, and /flux are properly mounted
# and accessible. It should be run periodically (e.g., via systemd timer)
# to detect mount failures early.
#
# Exit codes:
#   0 - All mounts healthy
#   1 - One or more mounts are unhealthy
#
# Usage:
#   ./check-motoko-storage-health.sh [--fix]
#   --fix: Attempt to automatically remount failed mounts

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Critical mount points and their expected UUIDs
declare -A MOUNT_UUIDS=(
    ["/time"]="f54cf57c-e434-45f5-bde3-cc706ffbe849"
    ["/space"]="7f5e508d-fcac-4d18-80ca-84c857b20b40"
    ["/flux"]="1ee5fe43-ad34-418c-a1b9-935daf594413"
)

FIX_MODE=false
FAILED=false

# Parse arguments
if [[ "${1:-}" == "--fix" ]]; then
    FIX_MODE=true
fi

log() { echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[FAIL]${NC} $1"; FAILED=true; }

log "=== Motoko Storage Health Check ==="

for mount_point in "${!MOUNT_UUIDS[@]}"; do
    expected_uuid="${MOUNT_UUIDS[$mount_point]}"
    
    # Check 1: Is it mounted?
    if ! mountpoint -q "$mount_point" 2>/dev/null; then
        error "$mount_point is NOT mounted"
        
        if $FIX_MODE; then
            log "Attempting to mount $mount_point..."
            if mount "$mount_point" 2>/dev/null; then
                success "Successfully mounted $mount_point"
                FAILED=false
            else
                error "Failed to mount $mount_point"
            fi
        fi
        continue
    fi
    
    # Check 2: Is the mount accessible?
    if ! ls "$mount_point" >/dev/null 2>&1; then
        error "$mount_point is mounted but NOT accessible (stale mount / I/O error)"
        
        # Check for emergency_ro flag (indicates filesystem errors)
        if mount | grep "$mount_point" | grep -q "emergency_ro"; then
            error "$mount_point has emergency_ro flag - filesystem errors detected!"
        fi
        
        if $FIX_MODE; then
            log "Attempting to remount $mount_point..."
            # Force unmount (lazy) and remount
            if umount -l "$mount_point" 2>/dev/null; then
                sleep 1
                if mount "$mount_point" 2>/dev/null; then
                    if ls "$mount_point" >/dev/null 2>&1; then
                        success "Successfully remounted $mount_point"
                        FAILED=false
                    else
                        error "Remounted $mount_point but still not accessible"
                    fi
                else
                    error "Failed to remount $mount_point"
                fi
            else
                error "Failed to unmount $mount_point for remount"
            fi
        fi
        continue
    fi
    
    # Check 3: Is it mounted from the correct UUID?
    current_device=$(findmnt -n -o SOURCE "$mount_point" 2>/dev/null || echo "unknown")
    
    if [[ "$current_device" != "unknown" ]]; then
        # Get UUID of the currently mounted device
        current_uuid=$(blkid -s UUID -o value "$current_device" 2>/dev/null || echo "unknown")
        
        if [[ "$current_uuid" != "$expected_uuid" ]]; then
            warn "$mount_point is mounted from unexpected device"
            warn "  Expected UUID: $expected_uuid"
            warn "  Actual UUID: $current_uuid"
            warn "  Device: $current_device"
        fi
    fi
    
    success "$mount_point is mounted and accessible"
done

# Check for stale/duplicate mounts (multiple devices on same mountpoint)
log "Checking for stale/duplicate mounts..."
for mount_point in "${!MOUNT_UUIDS[@]}"; do
    mount_count=$(mount | grep -c "on $mount_point " || true)
    if [[ "$mount_count" -gt 1 ]]; then
        error "$mount_point has $mount_count mounts (stale mount detected!)"
        warn "  Run: sudo umount -l $mount_point (multiple times) then: sudo mount $mount_point"
    fi
done

# Check Samba service
log "Checking Samba service..."
if systemctl is-active --quiet smb 2>/dev/null; then
    success "Samba (smb) service is running"
else
    error "Samba (smb) service is NOT running"
    if $FIX_MODE; then
        log "Attempting to start Samba..."
        if systemctl start smb 2>/dev/null; then
            success "Samba service started"
        else
            error "Failed to start Samba service"
        fi
    fi
fi

# Summary
log "=== Health Check Complete ==="
if $FAILED; then
    error "One or more checks failed!"
    exit 1
else
    success "All storage mounts are healthy"
    exit 0
fi

