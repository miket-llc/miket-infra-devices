#!/bin/bash
# Copyright (c) 2025 MikeT LLC. All rights reserved.
#
# test-autofs-count-zero.sh
# Test autofs configuration on count-zero
# Run this ON count-zero

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
echo "Autofs Configuration Test"
echo "=========================================="
echo ""

# Test 1: Check autofs master
log "1. Checking autofs master configuration..."
if grep -q "^/Volumes/motoko " /etc/auto_master 2>/dev/null; then
    success "Autofs master entry found"
    grep "^/Volumes/motoko " /etc/auto_master | sed 's/^/   /'
else
    error "Autofs master entry not found"
    echo "   Expected: /Volumes/motoko /etc/auto.motoko --timeout=300"
fi
echo ""

# Test 2: Check autofs map file
log "2. Checking autofs map file..."
if [ -f /etc/auto.motoko ]; then
    success "Autofs map file exists"
    echo "   Contents:"
    cat /etc/auto.motoko | sed 's/^/   /'
else
    error "Autofs map file not found: /etc/auto.motoko"
fi
echo ""

# Test 3: Check mount base
log "3. Checking mount base directory..."
if [ -d /Volumes/motoko ]; then
    success "Mount base exists: /Volumes/motoko"
    ls -ld /Volumes/motoko | sed 's/^/   /'
else
    error "Mount base does not exist: /Volumes/motoko"
fi
echo ""

# Test 4: Check user symlinks
log "4. Checking user symlinks..."
for share in flux space time; do
    LINK_PATH="$HOME/$share"
    TARGET_PATH="/Volumes/motoko/$share"
    
    if [ -L "$LINK_PATH" ]; then
        CURRENT=$(readlink "$LINK_PATH")
        if [ "$CURRENT" = "$TARGET_PATH" ]; then
            success "Symlink correct: $share -> $TARGET_PATH"
        else
            warn "Symlink incorrect: $share -> $CURRENT (expected $TARGET_PATH)"
        fi
    elif [ -e "$LINK_PATH" ]; then
        warn "$share exists but is not a symlink"
    else
        warn "Symlink missing: $share"
    fi
done
echo ""

# Test 5: Test mount (on-demand)
log "5. Testing on-demand mount..."
if [ -L "$HOME/space" ] && [ -e "$HOME/space" ]; then
    echo "   Accessing ~/space (this should trigger mount)..."
    if ls "$HOME/space" >/dev/null 2>&1; then
        success "Mount triggered successfully"
        sleep 2
        
        if mount | grep -q "on /Volumes/motoko/space"; then
            success "Space share is mounted"
            mount | grep "on /Volumes/motoko/space" | sed 's/^/   /'
        else
            warn "Space share not mounted (may need more time)"
        fi
    else
        error "Failed to access ~/space"
    fi
else
    warn "Cannot test mount - symlink not configured"
fi
echo ""

# Test 6: Check automountd status
log "6. Checking automountd status..."
if launchctl list | grep -q com.apple.automountd; then
    success "automountd is running"
else
    warn "automountd may not be running"
fi
echo ""

# Summary
echo "=========================================="
echo "Summary"
echo "=========================================="
echo ""

ALL_GOOD=true

if ! grep -q "^/Volumes/motoko " /etc/auto_master 2>/dev/null; then
    error "Autofs master not configured"
    ALL_GOOD=false
fi

if [ ! -f /etc/auto.motoko ]; then
    error "Autofs map file missing"
    ALL_GOOD=false
fi

if [ ! -d /Volumes/motoko ]; then
    error "Mount base missing"
    ALL_GOOD=false
fi

if [ "$ALL_GOOD" = true ]; then
    success "Autofs configuration looks good!"
    echo ""
    echo "To test mounts:"
    echo "  ls ~/space ~/flux ~/time"
    echo ""
    echo "To check mount status:"
    echo "  mount | grep autofs"
    echo "  mount | grep smbfs"
else
    error "Configuration incomplete"
    echo ""
    echo "Run the deployment script:"
    echo "  sudo ./scripts/deploy-autofs-count-zero.sh"
fi

