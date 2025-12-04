#!/bin/bash
# Copyright (c) 2025 MikeT LLC. All rights reserved.
#
# fix-nextcloud-case-clash.sh
# Fix case clash conflicts in Nextcloud sync on macOS
# Run this ON the macOS device experiencing the case clash

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
echo "Fix Nextcloud Case Clash Conflict"
echo "=========================================="
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

# Check for case clash conflicts
log "Checking for case clash conflicts..."

# Common case clash patterns
CLASH_PATTERNS=("Dashboard" "dashboard" "DASHBOARD")

FOUND_CLASH=false
for pattern in "${CLASH_PATTERNS[@]}"; do
    if [ -e "$SYNC_ROOT/$pattern" ] || [ -e "$SYNC_ROOT/${pattern,,}" ] || [ -e "$SYNC_ROOT/${pattern^^}" ]; then
        FOUND_CLASH=true
        break
    fi
done

if [ "$FOUND_CLASH" = false ]; then
    # Check if there are any case-sensitive duplicates
    if ls "$SYNC_ROOT"/[Dd]ashboard* 2>/dev/null | wc -l | grep -q "[2-9]"; then
        FOUND_CLASH=true
    fi
fi

if [ "$FOUND_CLASH" = false ]; then
    success "No obvious case clash conflicts found"
    info "If you're still seeing conflicts, they may be in subdirectories"
    echo ""
    info "To find all potential conflicts, run:"
    info "  find '$SYNC_ROOT' -iname 'dashboard' -type d"
    exit 0
fi

echo ""
warn "⚠️  Case clash conflict detected!"
echo ""
info "macOS is case-insensitive, so 'Dashboard' and 'dashboard' conflict."
info "We need to remove the old one and keep only the lowercase version."
echo ""

# Stop Nextcloud sync
log "Stopping Nextcloud sync..."
pkill -f "Nextcloud" 2>/dev/null || true
sleep 2

# Find and remove conflicting directories/files
log "Removing conflicting Dashboard directories..."

# Remove capital D Dashboard
if [ -d "$SYNC_ROOT/Dashboard" ]; then
    warn "Removing: $SYNC_ROOT/Dashboard"
    rm -rf "$SYNC_ROOT/Dashboard"
    success "Removed capital 'Dashboard' directory"
fi

# Remove any other case variations
for variant in "DASHBOARD" "Dashboard"; do
    if [ -e "$SYNC_ROOT/$variant" ]; then
        warn "Removing: $SYNC_ROOT/$variant"
        rm -rf "$SYNC_ROOT/$variant"
        success "Removed $variant"
    fi
done

# Ensure lowercase dashboard exists (will be synced from server)
if [ ! -d "$SYNC_ROOT/dashboard" ]; then
    info "Creating lowercase dashboard directory (will sync from server)..."
    mkdir -p "$SYNC_ROOT/dashboard"
fi

# Clean up Nextcloud cache to force re-sync
log "Clearing Nextcloud sync cache..."
CACHE_DIR="$HOME/Library/Caches/Nextcloud"
if [ -d "$CACHE_DIR" ]; then
    find "$CACHE_DIR" -name "*dashboard*" -type f -delete 2>/dev/null || true
    success "Cleared dashboard-related cache files"
fi

# Update exclude list to prevent Dashboard from syncing
EXCLUDE_FILE="$HOME/Library/Preferences/Nextcloud/sync-exclude.lst"
if [ -f "$EXCLUDE_FILE" ]; then
    if ! grep -q "^Dashboard$" "$EXCLUDE_FILE" 2>/dev/null; then
        log "Adding Dashboard to exclude list..."
        echo "" >> "$EXCLUDE_FILE"
        echo "# Exclude capital-case Dashboard (use lowercase dashboard)" >> "$EXCLUDE_FILE"
        echo "Dashboard" >> "$EXCLUDE_FILE"
        success "Added Dashboard to exclude list"
    fi
fi

# Restart Nextcloud
log "Restarting Nextcloud..."
open -a Nextcloud
sleep 3

echo ""
success "Case clash conflict resolved!"
echo ""
info "Next steps:"
info "1. Wait for Nextcloud to sync (check menu bar icon)"
info "2. If conflicts persist, go to Nextcloud Settings → Account → Selective sync"
info "3. Uncheck 'Dashboard' if it appears (we only want lowercase 'dashboard')"
info "4. The server-side mount uses lowercase 'dashboard' - this is correct"
echo ""
warn "Note: If the server still has 'Dashboard' (capital D), it needs to be renamed"
warn "on the server side. The mount should be '/dashboard' (lowercase)."
echo ""

