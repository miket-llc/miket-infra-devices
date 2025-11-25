#!/bin/bash
# Copyright (c) 2025 MikeT LLC. All rights reserved.

# transfer-tcc-blocked.sh
# Transfer TCC-protected directories that SSH cannot access
# Run this ON count-zero as miket user
# Total: ~116 GB | Estimated time: ~1 hour

set -euo pipefail

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
    exit 1
fi

log "Transferring TCC-protected directories to /space"
log "dev and Archives are already being transferred via SSH"
echo ""

RSYNC_OPTS="-av --progress --no-perms --no-owner --no-group --partial"

# 1. OneDrive MikeTLLC (4 GB)
if [[ -d ~/Library/CloudStorage/OneDrive-MikeTLLC ]]; then
    log "=== 1/3: OneDrive MikeTLLC (4 GB) ==="
    mkdir -p ~/.mkt/space/mike/_MAIN_FILES
    rsync $RSYNC_OPTS \
        ~/Library/CloudStorage/OneDrive-MikeTLLC/ \
        ~/.mkt/space/mike/_MAIN_FILES/ || warn "Some files may have failed"
    success "OneDrive complete"
else
    warn "OneDrive-MikeTLLC not found"
fi
echo ""

# 2. iCloud (54 GB)
if [[ -d ~/Library/Mobile\ Documents/com~apple~CloudDocs ]]; then
    log "=== 2/3: iCloud (54 GB) ==="
    mkdir -p ~/.mkt/space/devices/count-zero/icloud
    rsync $RSYNC_OPTS \
        ~/Library/Mobile\ Documents/com~apple~CloudDocs/ \
        ~/.mkt/space/devices/count-zero/icloud/ || warn "Some files may have failed"
    success "iCloud complete"
else
    warn "iCloud not found"
fi
echo ""

# 3. Downloads (58 GB)
if [[ -d ~/Downloads ]]; then
    log "=== 3/3: Downloads (58 GB) ==="
    mkdir -p ~/.mkt/space/devices/count-zero/downloads
    rsync $RSYNC_OPTS \
        ~/Downloads/ \
        ~/.mkt/space/devices/count-zero/downloads/ || warn "Some files may have failed"
    success "Downloads complete"
else
    warn "Downloads not found"
fi
echo ""

success "=== TCC-BLOCKED TRANSFERS COMPLETE ==="
log "Check SSH transfers for dev/archives: tail -f ~/.local/log/transfer-*.log on motoko"

