#!/bin/bash
# Copyright (c) 2025 MikeT LLC. All rights reserved.
#
# remove-dashboard-from-nextcloud-sync.sh
# Remove Dashboard directory from Nextcloud client sync on macOS
# Run this ON the macOS device where Dashboard is syncing

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() { echo -e "${CYAN}[$(date '+%H:%M:%S')]${NC} $1"; }
success() { echo -e "${GREEN}[$(date '+%H:%M:%S')] ✓${NC} $1"; }
warn() { echo -e "${YELLOW}[$(date '+%H:%M:%S')] ⚠${NC} $1"; }
error() { echo -e "${RED}[$(date '+%H:%M:%S')] ✗${NC} $1"; }
info() { echo -e "${BLUE}[$(date '+%H:%M:%S')] ℹ${NC} $1"; }

echo "=========================================="
echo "Remove Dashboard from Nextcloud Sync"
echo "=========================================="
echo ""
info "The Dashboard directory is a system directory for Data Estate Status."
info "It should not be synced to your local client."
echo ""

# Detect sync root
SYNC_ROOT="$HOME/nc"
if [ ! -d "$SYNC_ROOT" ]; then
    SYNC_ROOT="$HOME/cloud"
    if [ ! -d "$SYNC_ROOT" ]; then
        error "Could not find Nextcloud sync root (checked ~/nc and ~/cloud)"
        error "Please specify your sync root directory:"
        read -p "Sync root path: " SYNC_ROOT
        if [ ! -d "$SYNC_ROOT" ]; then
            error "Directory does not exist: $SYNC_ROOT"
            exit 1
        fi
    fi
fi

success "Found sync root: $SYNC_ROOT"
echo ""

# Check if Dashboard exists
DASHBOARD_PATH="$SYNC_ROOT/Dashboard"
if [ ! -d "$DASHBOARD_PATH" ]; then
    warn "Dashboard directory not found in sync root"
    info "It may have already been removed or never synced"
    exit 0
fi

log "Found Dashboard directory: $DASHBOARD_PATH"
echo ""

# Show what's in Dashboard
info "Contents of Dashboard directory:"
ls -lah "$DASHBOARD_PATH" | head -10 | sed 's/^/   /'
echo ""

# Confirm removal
warn "⚠️  This will remove the Dashboard directory from your local sync."
warn "   The Dashboard will still be available in Nextcloud web UI."
warn "   This is safe - Dashboard is read-only system data."
echo ""
read -p "Remove Dashboard from sync? (y/N): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    info "Cancelled. Dashboard will remain synced."
    exit 0
fi

# Stop Nextcloud sync temporarily
log "Stopping Nextcloud sync..."
pkill -f "Nextcloud" 2>/dev/null || true
sleep 2

# Remove Dashboard directory
log "Removing Dashboard directory..."
if [ -d "$DASHBOARD_PATH" ]; then
    rm -rf "$DASHBOARD_PATH"
    success "Removed: $DASHBOARD_PATH"
else
    warn "Dashboard directory already removed"
fi

# Add to exclude list
EXCLUDE_FILE="$HOME/Library/Preferences/Nextcloud/sync-exclude.lst"
if [ -f "$EXCLUDE_FILE" ]; then
    if grep -q "^Dashboard$" "$EXCLUDE_FILE" 2>/dev/null || grep -q "^dashboard$" "$EXCLUDE_FILE" 2>/dev/null; then
        success "Dashboard already in exclude list"
    else
        log "Adding Dashboard to exclude list..."
        echo "" >> "$EXCLUDE_FILE"
        echo "# Service/system directories (read-only, should not sync)" >> "$EXCLUDE_FILE"
        echo "Dashboard" >> "$EXCLUDE_FILE"
        success "Added Dashboard to exclude list: $EXCLUDE_FILE"
    fi
else
    warn "Exclude file not found: $EXCLUDE_FILE"
    warn "   You may need to manually exclude Dashboard in Nextcloud client settings"
fi

# Restart Nextcloud
log "Restarting Nextcloud..."
open -a Nextcloud
sleep 3

echo ""
success "Dashboard removed from sync!"
echo ""
info "Next steps:"
info "1. Open Nextcloud client settings"
info "2. Go to 'Account' → 'Selective sync'"
info "3. Make sure 'Dashboard' is unchecked"
info "4. The Dashboard will still be visible in Nextcloud web UI"
echo ""
info "The Dashboard directory contains Data Estate Status information"
info "and is meant to be viewed in the web UI, not synced locally."
echo ""

