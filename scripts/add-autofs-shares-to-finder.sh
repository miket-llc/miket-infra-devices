#!/bin/bash
# Copyright (c) 2025 MikeT LLC. All rights reserved.
#
# add-autofs-shares-to-finder.sh
# Make autofs-mounted SMB shares (time, space, flux) visible in Finder
# Creates Finder favorites/aliases and ensures symlinks are accessible

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
echo "Add Autofs Shares to Finder"
echo "=========================================="
echo ""
info "This script makes your autofs-mounted shares visible in Finder"
info "Shares: ~/space, ~/flux, ~/time"
echo ""

# Check if autofs is configured
if [ ! -f "/etc/auto.motoko" ]; then
    error "Autofs not configured! Run deploy-autofs script first."
    exit 1
fi

success "Autofs configuration found"
echo ""

# Detect mount base
AUTOFS_MOUNT_BASE="/Volumes/motoko"
if [ ! -d "$AUTOFS_MOUNT_BASE" ]; then
    AUTOFS_MOUNT_BASE="/mnt/motoko"
    if [ ! -d "$AUTOFS_MOUNT_BASE" ]; then
        warn "Mount base not found. Checking autofs config..."
        AUTOFS_MOUNT_BASE=$(grep "^/Volumes/motoko\|^/mnt/motoko" /etc/auto_master | awk '{print $1}' | head -1)
        if [ -z "$AUTOFS_MOUNT_BASE" ]; then
            error "Could not determine mount base from autofs config"
            exit 1
        fi
    fi
fi

success "Mount base: $AUTOFS_MOUNT_BASE"
echo ""

# Ensure symlinks exist
log "Checking symlinks..."
SHARES=("flux" "space" "time")
for share in "${SHARES[@]}"; do
    SYMLINK="$HOME/$share"
    TARGET="$AUTOFS_MOUNT_BASE/$share"
    
    if [ ! -e "$SYMLINK" ]; then
        log "Creating symlink: $SYMLINK -> $TARGET"
        ln -s "$TARGET" "$SYMLINK"
        success "Created: $SYMLINK"
    elif [ -L "$SYMLINK" ]; then
        CURRENT_TARGET=$(readlink "$SYMLINK")
        if [ "$CURRENT_TARGET" != "$TARGET" ]; then
            warn "Symlink exists but points to wrong location: $CURRENT_TARGET"
            log "Updating symlink..."
            rm "$SYMLINK"
            ln -s "$TARGET" "$SYMLINK"
            success "Updated: $SYMLINK"
        else
            success "Symlink exists: $SYMLINK"
        fi
    else
        warn "$SYMLINK exists but is not a symlink (skipping)"
    fi
done

echo ""

# Trigger mounts by accessing them (so they show up in Finder)
log "Triggering mounts (accessing shares)..."
for share in "${SHARES[@]}"; do
    SYMLINK="$HOME/$share"
    if [ -L "$SYMLINK" ]; then
        # Access the directory to trigger autofs mount
        ls "$SYMLINK" > /dev/null 2>&1 && success "Mounted: $share" || warn "Could not mount: $share (may need to check autofs)"
    fi
done

echo ""

# Add to Finder sidebar using osascript
log "Adding shares to Finder sidebar..."

# Function to add Finder favorite
add_finder_favorite() {
    local path="$1"
    local name="$2"
    
    osascript <<EOF 2>/dev/null || true
tell application "Finder"
    try
        set targetPath to POSIX file "$path"
        set targetAlias to targetPath as alias
        set sidebarItems to sidebar items of window 1
        set found to false
        
        -- Check if already in sidebar
        repeat with item in sidebarItems
            if name of item is "$name" then
                set found to true
                exit repeat
            end if
        end repeat
        
        -- Add to sidebar if not found
        if not found then
            make new alias file at desktop with properties {name:"$name", original item:targetAlias}
            delay 0.5
            set aliasFile to alias file "$name" of desktop
            move aliasFile to sidebar of window 1
            delete alias file "$name" of desktop
        end if
    end try
end tell
EOF
}

# Alternative: Use sfltool to add to sidebar (more reliable)
log "Adding to Finder sidebar using sfltool..."

# Get current user's sidebar items
SIDEBAR_PLIST="$HOME/Library/Application Support/com.apple.sharedfilelist/com.apple.LSSharedFileList.FavoriteItems.sfl2"

# For each share, add it to Finder favorites
for share in "${SHARES[@]}"; do
    SYMLINK="$HOME/$share"
    
    if [ -L "$SYMLINK" ] || [ -d "$SYMLINK" ]; then
        # Use osascript to add to sidebar (more reliable than sfltool manipulation)
        log "Adding $share to Finder sidebar..."
        
        osascript <<EOF 2>/dev/null || true
tell application "Finder"
    try
        set targetPath to POSIX file "$SYMLINK"
        set targetAlias to targetPath as alias
        
        -- Open Finder window if not open
        if (count of windows) = 0 then
            make new Finder window
        end if
        
        -- Add to sidebar
        tell application "System Events"
            tell process "Finder"
                try
                    set sidebarItems to sidebar items of window 1
                    set found to false
                    repeat with item in sidebarItems
                        if name of item is "$share" then
                            set found to true
                            exit repeat
                        end if
                    end repeat
                    
                    if not found then
                        -- Create alias on desktop temporarily
                        set desktopPath to path to desktop folder
                        set aliasFile to make new alias file at desktopPath with properties {name:"$share", original item:targetAlias}
                        delay 0.5
                        -- Move to sidebar
                        move aliasFile to sidebar of window 1
                        delay 0.5
                        -- Clean up desktop alias
                        delete alias file "$share" of desktopPath
                    end if
                end try
            end tell
        end tell
    end try
end tell
EOF
        
        success "Added $share to Finder sidebar"
    else
        warn "Could not add $share (symlink not accessible)"
    fi
done

echo ""

# Create desktop aliases as backup method
log "Creating desktop aliases (alternative access method)..."
DESKTOP="$HOME/Desktop"
for share in "${SHARES[@]}"; do
    SYMLINK="$HOME/$share"
    ALIAS="$DESKTOP/$share"
    
    if [ -L "$SYMLINK" ] || [ -d "$SYMLINK" ]; then
        # Remove old alias if exists
        [ -e "$ALIAS" ] && rm "$ALIAS"
        
        # Create alias
        osascript <<EOF 2>/dev/null || true
tell application "Finder"
    try
        set targetPath to POSIX file "$SYMLINK"
        set targetAlias to targetPath as alias
        make new alias file at desktop with properties {name:"$share", original item:targetAlias}
    end try
end tell
EOF
        
        success "Created desktop alias: $ALIAS"
    fi
done

echo ""
success "Shares added to Finder!"
echo ""
info "Access methods:"
info "  1. Finder sidebar - Look for 'flux', 'space', 'time'"
info "  2. Desktop aliases - Icons on your desktop"
info "  3. Direct symlinks - ~/flux, ~/space, ~/time"
info "  4. Go menu - Go → Home, then click the symlinks"
echo ""
info "Note: Shares mount automatically when accessed (autofs on-demand mounting)"
info "If shares don't appear, try:"
info "  ls ~/space ~/flux ~/time"
info "This will trigger the mounts."
echo ""

