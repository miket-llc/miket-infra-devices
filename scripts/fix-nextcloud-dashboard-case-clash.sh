#!/bin/bash
# Copyright (c) 2025 MikeT LLC. All rights reserved.
#
# fix-nextcloud-dashboard-case-clash.sh
# Fix Dashboard/dashboard case clash conflict in Nextcloud sync on macOS
# This removes the old capital-D Dashboard and ensures only lowercase dashboard exists

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
echo "Fix Nextcloud Dashboard Case Clash"
echo "=========================================="
echo ""
info "This script fixes the case clash between 'Dashboard' and 'dashboard'"
info "macOS is case-insensitive, so these conflict."
echo ""

# Detect sync root
SYNC_ROOT="$HOME/nc"
if [ ! -d "$SYNC_ROOT" ]; then
    SYNC_ROOT="$HOME/cloud"
    if [ ! -d "$SYNC_ROOT" ]; then
        error "Could not find Nextcloud sync root (checked ~/nc and ~/cloud)"
        read -p "Enter your sync root path: " SYNC_ROOT
        if [ ! -d "$SYNC_ROOT" ]; then
            error "Directory does not exist: $SYNC_ROOT"
            exit 1
        fi
    fi
fi

success "Found sync root: $SYNC_ROOT"
echo ""

# Stop Nextcloud sync first
log "Stopping Nextcloud sync..."
pkill -f "Nextcloud" 2>/dev/null || true
sleep 2
success "Nextcloud stopped"
echo ""

# Check what exists
DASHBOARD_UPPER="$SYNC_ROOT/Dashboard"
DASHBOARD_LOWER="$SYNC_ROOT/dashboard"

log "Checking for conflicting directories..."

if [ -e "$DASHBOARD_UPPER" ]; then
    warn "Found: $DASHBOARD_UPPER"
    ls -ld "$DASHBOARD_UPPER" | sed 's/^/   /'
fi

if [ -e "$DASHBOARD_LOWER" ]; then
    success "Found: $DASHBOARD_LOWER"
    ls -ld "$DASHBOARD_LOWER" | sed 's/^/   /'
fi

echo ""

# Remove capital D Dashboard (old, incorrect)
if [ -e "$DASHBOARD_UPPER" ]; then
    warn "⚠️  Removing old capital-D 'Dashboard' directory..."
    rm -rf "$DASHBOARD_UPPER"
    success "Removed: $DASHBOARD_UPPER"
else
    info "No capital-D Dashboard found (good!)"
fi

# Ensure lowercase dashboard exists (will sync from server)
if [ ! -e "$DASHBOARD_LOWER" ]; then
    info "Creating lowercase dashboard directory (will sync from server)..."
    mkdir -p "$DASHBOARD_LOWER"
    success "Created: $DASHBOARD_LOWER"
fi

# Clean up Nextcloud cache
log "Clearing Nextcloud cache for dashboard..."
CACHE_DIR="$HOME/Library/Caches/Nextcloud"
if [ -d "$CACHE_DIR" ]; then
    find "$CACHE_DIR" -iname "*dashboard*" -type f -delete 2>/dev/null || true
    success "Cleared dashboard cache"
fi

# Update exclude list
EXCLUDE_FILE="$HOME/Library/Preferences/Nextcloud/sync-exclude.lst"
if [ -f "$EXCLUDE_FILE" ]; then
    # Remove any Dashboard entries (capital D)
    if grep -q "^Dashboard$" "$EXCLUDE_FILE" 2>/dev/null; then
        log "Removing capital-D Dashboard from exclude list..."
        sed -i '' '/^Dashboard$/d' "$EXCLUDE_FILE"
        success "Removed Dashboard from exclude list"
    fi
    
    # Ensure lowercase dashboard is NOT excluded (we want it to sync)
    if grep -q "^dashboard$" "$EXCLUDE_FILE" 2>/dev/null; then
        log "Removing lowercase dashboard from exclude list (we want it to sync)..."
        sed -i '' '/^dashboard$/d' "$EXCLUDE_FILE"
        success "Removed dashboard from exclude list"
    fi
else
    warn "Exclude file not found: $EXCLUDE_FILE"
fi

# Restart Nextcloud
log "Restarting Nextcloud..."
open -a Nextcloud
sleep 3

echo ""
success "Case clash fixed!"
echo ""
info "Summary:"
info "  ✓ Removed capital-D 'Dashboard' directory"
info "  ✓ Kept lowercase 'dashboard' directory"
info "  ✓ Cleared Nextcloud cache"
info "  ✓ Restarted Nextcloud"
echo ""
warn "IMPORTANT: If the server still has '/Dashboard' (capital D) mount,"
warn "it needs to be removed and recreated as '/dashboard' (lowercase)."
warn ""
warn "On motoko, run:"
warn "  ssh mdt@motoko"
warn "  podman exec -u 33 nextcloud-app php occ files_external:delete Dashboard"
warn "  # Then redeploy to recreate as lowercase"
echo ""
info "The mount should be '/dashboard' (lowercase) to avoid macOS conflicts."
echo ""

