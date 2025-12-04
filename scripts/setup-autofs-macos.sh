#!/bin/bash
# Copyright (c) 2025 MikeT LLC. All rights reserved.
#
# setup-autofs-macos.sh
# Deploy autofs configuration and create symlinks for macOS
# Uses osascript to prompt for sudo password in GUI

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
echo "Setup Autofs and Create Symlinks"
echo "=========================================="
echo ""

# Check if mounts.env exists
SMB_ENV_FILE="${HOME}/.mkt/mounts.env"
if [ ! -f "$SMB_ENV_FILE" ]; then
    error "Mounts env file not found: $SMB_ENV_FILE"
    error "Please run secrets-sync playbook first"
    exit 1
fi

success "Found mounts.env file"
echo ""

# Read password from env file
log "Reading SMB password from env file..."
set -o allexport
source "$SMB_ENV_FILE"
set +o allexport

if [ -z "${SMB_PASSWORD:-}" ]; then
    error "SMB_PASSWORD not found in $SMB_ENV_FILE"
    exit 1
fi

success "Password loaded"
echo ""

# URL encode password
log "Encoding password..."
SMB_PASSWORD_ENCODED=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$SMB_PASSWORD', safe=''))")
success "Password encoded"
echo ""

# Configuration
SMB_SERVER="motoko"
SMB_USERNAME="mdt"
AUTOFS_MOUNT_BASE="/Volumes/motoko"
AUTOFS_TIMEOUT=300
AUTOFS_MASTER="/etc/auto_master"
AUTOFS_MAP="/etc/auto.motoko"

log "Configuration:"
info "  Server: $SMB_SERVER"
info "  Username: $SMB_USERNAME"
info "  Mount base: $AUTOFS_MOUNT_BASE"
info "  Timeout: ${AUTOFS_TIMEOUT}s"
echo ""

# Clean up old mounts and symlinks
log "Cleaning up old mounts and symlinks..."
umount ~/.mkt/flux ~/.mkt/space ~/.mkt/time 2>/dev/null || true
launchctl unload ~/Library/LaunchAgents/com.miket.storage-connect.plist 2>/dev/null || true
rm -f ~/flux ~/space ~/time
success "Cleanup complete"
echo ""

# Prompt for sudo password using osascript
log "Prompting for sudo password..."
SUDO_PASSWORD=$(osascript <<EOF 2>/dev/null
tell application "System Events"
    activate
    display dialog "Autofs setup requires administrator privileges. Please enter your password:" default answer "" with hidden answer with title "Sudo Password" buttons {"Cancel", "OK"} default button "OK"
    return text returned of result
end tell
EOF
)

if [ -z "$SUDO_PASSWORD" ]; then
    error "Password prompt cancelled"
    exit 1
fi

success "Password obtained"
echo ""

# Configure autofs using sudo with password
log "Configuring autofs..."

echo "$SUDO_PASSWORD" | sudo -S bash <<EOF
set -euo pipefail

# Create mount base (use /Volumes - macOS SIP makes /mnt read-only)
mkdir -p "$AUTOFS_MOUNT_BASE"
chmod 755 "$AUTOFS_MOUNT_BASE"
echo "Created mount base: $AUTOFS_MOUNT_BASE"

# Add to auto_master
if ! grep -q "^${AUTOFS_MOUNT_BASE} " "$AUTOFS_MASTER"; then
    echo "${AUTOFS_MOUNT_BASE} ${AUTOFS_MAP} --timeout=${AUTOFS_TIMEOUT}" >> "$AUTOFS_MASTER"
    echo "Added entry to $AUTOFS_MASTER"
else
    echo "Entry already exists in $AUTOFS_MASTER"
fi

# Create autofs map
cat > "$AUTOFS_MAP" <<AUTOMAP
# Autofs map for motoko SMB shares
# Auto-generated - do not edit manually
#
# Shares are mounted on-demand when accessed, unmounted after ${AUTOFS_TIMEOUT}s idle
#
flux -fstype=smbfs,soft,noowners,nosuid,rw ://${SMB_USERNAME}:${SMB_PASSWORD_ENCODED}@${SMB_SERVER}/flux
space -fstype=smbfs,soft,noowners,nosuid,rw ://${SMB_USERNAME}:${SMB_PASSWORD_ENCODED}@${SMB_SERVER}/space
time -fstype=smbfs,soft,noowners,nosuid,rw ://${SMB_USERNAME}:${SMB_PASSWORD_ENCODED}@${SMB_SERVER}/time
AUTOMAP

chmod 600 "$AUTOFS_MAP"  # Restrictive permissions - contains URL-encoded password
echo "Created autofs map: $AUTOFS_MAP"

# Create symlinks
for share in flux space time; do
    rm -f /Users/miket/\$share
    ln -s ${AUTOFS_MOUNT_BASE}/\$share /Users/miket/\$share
    echo "Created symlink: /Users/miket/\$share -> ${AUTOFS_MOUNT_BASE}/\$share"
done

# Reload autofs
automount -vc
echo "Reloaded autofs configuration"
EOF

if [ $? -eq 0 ]; then
    success "Autofs configured successfully"
else
    error "Autofs configuration failed"
    exit 1
fi

echo ""

# Test mounts
log "Testing mounts..."
sleep 2

for share in flux space time; do
    SYMLINK="$HOME/$share"
    if [ -L "$SYMLINK" ]; then
        # Trigger mount by accessing
        if ls "$SYMLINK" > /dev/null 2>&1; then
            success "Mounted: $share"
        else
            warn "Could not mount: $share (may need to check connectivity)"
        fi
    else
        error "Symlink not found: $SYMLINK"
    fi
done

echo ""

# Show status
log "Mount status:"
mount | grep autofs || info "No autofs mounts yet (will mount on access)"
mount | grep smbfs || info "No SMB mounts yet (will mount on access)"

echo ""
log "Symlink status:"
ls -la ~/flux ~/space ~/time 2>&1 | sed 's/^/   /' || warn "Symlinks not accessible"

echo ""
success "Setup complete!"
echo ""
info "Access your shares:"
info "  ~/flux  - Runtime data (apps, DBs, models)"
info "  ~/space - System of Record (all files)"
info "  ~/time  - Time Machine backups"
echo ""
info "Shares mount automatically when accessed (autofs on-demand mounting)"
info "To add to Finder sidebar, run:"
info "  ./scripts/add-autofs-shares-to-finder.sh"
echo ""

