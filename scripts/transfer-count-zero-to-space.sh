#!/bin/bash
# transfer-count-zero-to-space.sh
# Transfer all user data from count-zero to /space via SMB mount
# Run this ON count-zero as miket user
# Total: ~372 GB | Estimated time: 2-4 hours

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log() { echo -e "${CYAN}[$(date '+%H:%M:%S')]${NC} $1"; }
success() { echo -e "${GREEN}[$(date '+%H:%M:%S')] ✓${NC} $1"; }
warn() { echo -e "${YELLOW}[$(date '+%H:%M:%S')] ⚠${NC} $1"; }

# Check SMB mount
if [[ ! -d ~/.mkt/space ]]; then
    echo "ERROR: SMB mount not found at ~/.mkt/space"
    echo "Please ensure motoko shares are mounted first."
    exit 1
fi

# Test write access
if ! touch ~/.mkt/space/.transfer-test 2>/dev/null; then
    echo "ERROR: Cannot write to ~/.mkt/space"
    exit 1
fi
rm -f ~/.mkt/space/.transfer-test

log "Starting transfer to /space via SMB mount"
log "Total estimated: ~372 GB"
echo ""

# Common rsync options
RSYNC_OPTS="-av --progress --no-perms --no-owner --no-group --partial"

# 1. OneDrive MikeTLLC (4 GB)
if [[ -d ~/Library/CloudStorage/OneDrive-MikeTLLC ]]; then
    log "=== 1/5: OneDrive MikeTLLC (4 GB) → /space/mike/_MAIN_FILES/ ==="
    mkdir -p ~/.mkt/space/mike/_MAIN_FILES
    rsync $RSYNC_OPTS \
        ~/Library/CloudStorage/OneDrive-MikeTLLC/ \
        ~/.mkt/space/mike/_MAIN_FILES/ || warn "Some files may have failed"
    success "OneDrive MikeTLLC complete"
else
    warn "OneDrive-MikeTLLC not found, skipping"
fi
echo ""

# 2. iCloud (54 GB)
if [[ -d ~/Library/Mobile\ Documents/com~apple~CloudDocs ]]; then
    log "=== 2/5: iCloud (54 GB) → /space/devices/count-zero/icloud/ ==="
    mkdir -p ~/.mkt/space/devices/count-zero/icloud
    rsync $RSYNC_OPTS \
        ~/Library/Mobile\ Documents/com~apple~CloudDocs/ \
        ~/.mkt/space/devices/count-zero/icloud/ || warn "Some files may have failed"
    success "iCloud complete"
else
    warn "iCloud not found, skipping"
fi
echo ""

# 3. Downloads (58 GB)
if [[ -d ~/Downloads ]]; then
    log "=== 3/5: Downloads (58 GB) → /space/devices/count-zero/downloads/ ==="
    mkdir -p ~/.mkt/space/devices/count-zero/downloads
    rsync $RSYNC_OPTS \
        ~/Downloads/ \
        ~/.mkt/space/devices/count-zero/downloads/ || warn "Some files may have failed"
    success "Downloads complete"
else
    warn "Downloads not found, skipping"
fi
echo ""

# 4. dev (170 GB)
if [[ -d ~/dev ]]; then
    log "=== 4/5: dev (170 GB) → /space/mike/dev/ ==="
    mkdir -p ~/.mkt/space/mike/dev
    rsync $RSYNC_OPTS \
        ~/dev/ \
        ~/.mkt/space/mike/dev/ || warn "Some files may have failed"
    success "dev complete"
else
    warn "dev directory not found, skipping"
fi
echo ""

# 5. Archives (86 GB)
if [[ -d ~/Archives ]]; then
    log "=== 5/5: Archives (86 GB) → /space/mike/archives/ ==="
    mkdir -p ~/.mkt/space/mike/archives
    rsync $RSYNC_OPTS \
        ~/Archives/ \
        ~/.mkt/space/mike/archives/ || warn "Some files may have failed"
    success "Archives complete"
else
    warn "Archives not found, skipping"
fi
echo ""

success "=== ALL TRANSFERS COMPLETE ==="
log "Data now in /space on motoko"
log "Verify with: ls -la ~/.mkt/space/mike/ ~/.mkt/space/devices/count-zero/"

