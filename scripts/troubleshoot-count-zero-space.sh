#!/bin/bash
# Copyright (c) 2025 MikeT LLC. All rights reserved.
#
# troubleshoot-count-zero-space.sh
# Diagnose why space directory is empty or not visible on count-zero
# Run this ON count-zero as the user experiencing the issue

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log() { echo -e "${CYAN}[$(date '+%H:%M:%S')]${NC} $1"; }
success() { echo -e "${GREEN}[$(date '+%H:%M:%S')] ✓${NC} $1"; }
warn() { echo -e "${YELLOW}[$(date '+%H:%M:%S')] ⚠${NC} $1"; }
error() { echo -e "${RED}[$(date '+%H:%M:%S')] ✗${NC} $1"; }

SPACE_MOUNT="${HOME}/.mkt/space"
SMB_SERVER="motoko"
SECRETS_FILE="${HOME}/.mkt/mounts.env"

echo "=========================================="
echo "Space Directory Troubleshooting"
echo "=========================================="
echo ""

# 1. Check if mount point directory exists
log "1. Checking mount point directory..."
if [[ -d "$SPACE_MOUNT" ]]; then
    success "Mount point exists: $SPACE_MOUNT"
else
    error "Mount point does not exist: $SPACE_MOUNT"
    echo "   Run: ansible-playbook -i inventory/hosts.yml playbooks/mount-shares-count-zero.yml"
    exit 1
fi
echo ""

# 2. Check if space is actually mounted
log "2. Checking if space is mounted..."
if mount | grep -q "on ${SPACE_MOUNT} "; then
    success "Space is mounted"
    MOUNT_INFO=$(mount | grep "on ${SPACE_MOUNT} ")
    echo "   Mount info: $MOUNT_INFO"
else
    error "Space is NOT mounted"
    echo "   The directory exists but is not mounted via SMB"
fi
echo ""

# 3. Check mount contents
log "3. Checking mount contents..."
if [[ -d "$SPACE_MOUNT" ]]; then
    FILE_COUNT=$(find "$SPACE_MOUNT" -mindepth 1 -maxdepth 1 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$FILE_COUNT" -eq 0 ]]; then
        warn "Mount directory is empty (0 items)"
    else
        success "Mount directory contains $FILE_COUNT items"
        echo "   Top-level contents:"
        ls -la "$SPACE_MOUNT" | head -10 | sed 's/^/   /'
    fi
fi
echo ""

# 4. Check SMB secrets file
log "4. Checking SMB credentials..."
if [[ -f "$SECRETS_FILE" ]]; then
    success "Secrets file exists: $SECRETS_FILE"
    if [[ -r "$SECRETS_FILE" ]]; then
        success "Secrets file is readable"
        # Check if SMB_PASSWORD is set (without showing the password)
        if grep -q "^SMB_PASSWORD=" "$SECRETS_FILE"; then
            success "SMB_PASSWORD is set in secrets file"
        else
            error "SMB_PASSWORD not found in secrets file"
        fi
    else
        error "Secrets file is not readable"
        echo "   Run: chmod 600 $SECRETS_FILE"
    fi
else
    error "Secrets file missing: $SECRETS_FILE"
    echo "   Run: ansible-playbook -i inventory/hosts.yml playbooks/secrets-sync.yml --limit count-zero"
fi
echo ""

# 5. Check network connectivity to motoko
log "5. Checking network connectivity to $SMB_SERVER..."
if ping -c 2 "$SMB_SERVER" &>/dev/null; then
    success "Can ping $SMB_SERVER"
else
    error "Cannot ping $SMB_SERVER"
    echo "   Check Tailscale connectivity: tailscale status"
fi
echo ""

# 6. Check SMB connectivity
log "6. Testing SMB connectivity..."
if command -v smbclient &>/dev/null; then
    if [[ -f "$SECRETS_FILE" ]]; then
        source "$SECRETS_FILE"
        if smbclient -L "//${SMB_SERVER}/space" -U "${SMB_USERNAME:-mdt}" -N 2>/dev/null | head -5 &>/dev/null; then
            success "SMB connection to //${SMB_SERVER}/space works"
        else
            warn "SMB connection test failed (may need password)"
            echo "   Testing with credentials from secrets file..."
        fi
    else
        warn "Cannot test SMB - secrets file missing"
    fi
else
    warn "smbclient not installed (optional for testing)"
fi
echo ""

# 7. Check LaunchAgent status
log "7. Checking LaunchAgent status..."
if launchctl list | grep -q "com.miket.storage-connect"; then
    success "LaunchAgent is loaded"
    LAUNCHCTL_STATUS=$(launchctl list | grep "com.miket.storage-connect")
    echo "   $LAUNCHCTL_STATUS"
else
    warn "LaunchAgent not found or not loaded"
    echo "   Expected: com.miket.storage-connect"
fi
echo ""

# 8. Check mount script
log "8. Checking mount script..."
MOUNT_SCRIPT="${HOME}/.scripts/mount_shares.sh"
if [[ -f "$MOUNT_SCRIPT" ]]; then
    success "Mount script exists: $MOUNT_SCRIPT"
    if [[ -x "$MOUNT_SCRIPT" ]]; then
        success "Mount script is executable"
    else
        warn "Mount script is not executable"
        echo "   Run: chmod +x $MOUNT_SCRIPT"
    fi
else
    error "Mount script missing: $MOUNT_SCRIPT"
    echo "   Run: ansible-playbook -i inventory/hosts.yml playbooks/mount-shares-count-zero.yml"
fi
echo ""

# 9. Check mount log
log "9. Checking mount log..."
MOUNT_LOG="${HOME}/.scripts/mount_shares.log"
if [[ -f "$MOUNT_LOG" ]]; then
    success "Mount log exists: $MOUNT_LOG"
    echo "   Last 10 lines:"
    tail -10 "$MOUNT_LOG" | sed 's/^/   /'
else
    warn "Mount log not found (script may not have run yet)"
fi
echo ""

# 10. Test manual mount
log "10. Testing manual mount..."
if [[ -f "$MOUNT_SCRIPT" ]] && [[ -x "$MOUNT_SCRIPT" ]]; then
    echo "   Attempting to run mount script..."
    if "$MOUNT_SCRIPT" 2>&1 | tail -5; then
        # Re-check mount status
        sleep 2
        if mount | grep -q "on ${SPACE_MOUNT} "; then
            success "Manual mount succeeded!"
        else
            warn "Mount script ran but space still not mounted"
            echo "   Check the mount log for errors: $MOUNT_LOG"
        fi
    else
        error "Mount script failed"
        echo "   Check the mount log for details: $MOUNT_LOG"
    fi
else
    warn "Cannot test manual mount - script missing or not executable"
fi
echo ""

# 11. Check symlink
log "11. Checking user symlink..."
SYMLINK="${HOME}/space"
if [[ -L "$SYMLINK" ]]; then
    success "Symlink exists: $SYMLINK"
    TARGET=$(readlink "$SYMLINK")
    echo "   Points to: $TARGET"
    if [[ -e "$SYMLINK" ]]; then
        success "Symlink target is accessible"
    else
        warn "Symlink target is not accessible (mount may be down)"
    fi
elif [[ -e "$SYMLINK" ]]; then
    warn "$SYMLINK exists but is not a symlink"
else
    warn "Symlink does not exist: $SYMLINK"
fi
echo ""

# Summary and recommendations
echo "=========================================="
echo "Summary and Recommendations"
echo "=========================================="
echo ""

if mount | grep -q "on ${SPACE_MOUNT} "; then
    if [[ -d "$SPACE_MOUNT" ]]; then
        FILE_COUNT=$(find "$SPACE_MOUNT" -mindepth 1 -maxdepth 1 2>/dev/null | wc -l | tr -d ' ')
        if [[ "$FILE_COUNT" -eq 0 ]]; then
            error "ISSUE: Space is mounted but appears empty"
            echo ""
            echo "Possible causes:"
            echo "  1. Permissions issue - SMB user may not have access"
            echo "  2. Mount point is stale - try unmounting and remounting"
            echo "  3. SMB share path is incorrect"
            echo ""
            echo "Try these fixes:"
            echo "  # Unmount and remount"
            echo "  umount $SPACE_MOUNT"
            echo "  ~/.scripts/mount_shares.sh"
            echo ""
            echo "  # Check SMB share on motoko"
            echo "  tailscale ssh motoko 'ls -la /space'"
        else
            success "Space is mounted and contains files"
        fi
    fi
else
    error "ISSUE: Space is not mounted"
    echo ""
    echo "Try these fixes:"
    echo "  1. Run mount script manually:"
    echo "     ~/.scripts/mount_shares.sh"
    echo ""
    echo "  2. Check credentials:"
    echo "     cat $SECRETS_FILE"
    echo ""
    echo "  3. Reload LaunchAgent:"
    echo "     launchctl unload ~/Library/LaunchAgents/com.miket.storage-connect.plist"
    echo "     launchctl load ~/Library/LaunchAgents/com.miket.storage-connect.plist"
    echo ""
    echo "  4. Re-run Ansible playbook:"
    echo "     ansible-playbook -i inventory/hosts.yml playbooks/mount-shares-count-zero.yml"
fi

echo ""
log "Troubleshooting complete"

