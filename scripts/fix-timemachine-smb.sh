#!/bin/bash
# Copyright (c) 2025 MikeT LLC. All rights reserved.
#
# fix-timemachine-smb.sh
# Fix Time Machine SMB connection issues on macOS
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

echo "=========================================="
echo "Time Machine SMB Fix Script"
echo "=========================================="
echo ""

# Step 1: Stop Time Machine
log "1. Stopping Time Machine..."
tmutil stopbackup 2>&1 || true
sleep 2
success "Time Machine stopped"
echo ""

# Step 2: Fix regular SMB mounts
log "2. Checking and fixing regular SMB mounts..."
if [ -f ~/.scripts/mount_shares.sh ]; then
    ~/.scripts/mount_shares.sh 2>&1 | tail -10
    success "Mount script executed"
else
    warn "Mount script not found at ~/.scripts/mount_shares.sh"
fi
echo ""

# Step 3: Verify network connectivity
log "3. Verifying network connectivity..."
if ping -c 2 motoko.pangolin-vega.ts.net &>/dev/null; then
    success "Network connectivity OK"
else
    error "Cannot reach motoko.pangolin-vega.ts.net"
    echo "   Check Tailscale: tailscale status"
    exit 1
fi
echo ""

# Step 4: Open Time Machine share in Finder to refresh mount
log "4. Opening Time Machine share in Finder to refresh mount..."
open "smb://mdt@motoko.pangolin-vega.ts.net/time" 2>&1 || true
sleep 3
success "Share opened in Finder"
echo ""

# Step 5: Check Time Machine mount
log "5. Checking Time Machine mount..."
TM_MOUNT=$(mount | grep -i "timemachine.*motoko" | head -1 | awk '{print $3}' || echo "")
if [ -n "$TM_MOUNT" ]; then
    success "Time Machine mount found: $TM_MOUNT"
    if df -h | grep -q "motoko.*time"; then
        success "Time Machine mount is accessible"
    else
        warn "Time Machine mount may be stale"
    fi
else
    warn "Time Machine mount not found (will be created on next backup)"
fi
echo ""

# Step 6: Restart Time Machine
log "6. Restarting Time Machine..."
tmutil startbackup --auto 2>&1 || true
sleep 3
success "Time Machine restarted"
echo ""

# Step 7: Check status
log "7. Checking Time Machine status..."
sleep 5
TM_STATUS=$(tmutil status 2>&1)
if echo "$TM_STATUS" | grep -q "Running = 1"; then
    success "Time Machine is running"
    echo "$TM_STATUS" | grep -E "(BackupPhase|Percent|Running)" | sed 's/^/   /'
    
    BACKUP_PHASE=$(echo "$TM_STATUS" | grep "BackupPhase" | awk -F'= ' '{print $2}' | tr -d ';')
    if [ "$BACKUP_PHASE" = "FindingBackupVol" ]; then
        warn "Time Machine is still in FindingBackupVol phase"
        echo ""
        echo "If this persists, you may need to:"
        echo "  1. Remove and re-add Time Machine destination (requires admin):"
        echo "     sudo tmutil removedestination <DESTINATION_ID>"
        echo "     # Then add via System Settings > Time Machine"
        echo ""
        echo "  2. Or wait a few minutes - Time Machine may need time to rediscover the volume"
    else
        success "Time Machine backup phase: $BACKUP_PHASE"
    fi
elif echo "$TM_STATUS" | grep -q "Running = 0"; then
    success "Time Machine is idle (will start automatically)"
else
    warn "Could not determine Time Machine status"
fi
echo ""

echo "=========================================="
echo "Fix Complete"
echo "=========================================="
echo ""
echo "Next steps:"
echo "  1. Monitor Time Machine in System Settings > Time Machine"
echo "  2. Check if backup progresses past 'FindingBackupVol' phase"
echo "  3. If still stuck, run: ./scripts/diagnose-timemachine-smb.sh"
echo ""
log "Script complete"

