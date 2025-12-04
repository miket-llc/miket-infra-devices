#!/bin/bash
# Copyright (c) 2025 MikeT LLC. All rights reserved.
#
# fix-nextcloud-connection.sh
# Quick fix for Nextcloud client connection issues on macOS
# Run this ON the macOS device experiencing the connection issue

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

# Nextcloud server URLs
TAILSCALE_URL="https://motoko.pangolin-vega.ts.net"
CLOUDFLARE_URL="https://nextcloud.miket.io"

echo "=========================================="
echo "Nextcloud Connection Quick Fix"
echo "=========================================="
echo ""

# Step 1: Ensure Nextcloud is installed
log "Step 1: Checking Nextcloud installation..."
if [ ! -d "/Applications/Nextcloud.app" ]; then
    warn "Nextcloud.app not found. Installing..."
    if command -v brew > /dev/null 2>&1; then
        brew install --cask nextcloud
        success "Nextcloud installed via Homebrew"
    else
        error "Homebrew not found. Please install Nextcloud manually:"
        error "  https://nextcloud.com/install/#install-clients"
        exit 1
    fi
else
    success "Nextcloud.app is installed"
fi
echo ""

# Step 2: Ensure Tailscale is running
log "Step 2: Checking Tailscale connectivity..."
if command -v tailscale > /dev/null 2>&1; then
    if tailscale status 2>/dev/null | grep -q "100\."; then
        success "Tailscale is connected"
    else
        warn "Tailscale is not connected. Attempting to start..."
        # Try to start Tailscale daemon
        if [ -f "/Library/LaunchDaemons/com.tailscale.tailscaled.plist" ]; then
            sudo launchctl load /Library/LaunchDaemons/com.tailscale.tailscaled.plist 2>/dev/null || true
            sleep 3
            if tailscale status 2>/dev/null | grep -q "100\."; then
                success "Tailscale started successfully"
            else
                warn "Tailscale may need manual authentication"
                warn "   Check Tailscale menu bar icon or run: tailscale up"
            fi
        else
            warn "Tailscale daemon not found. Please install Tailscale first."
        fi
    fi
else
    warn "Tailscale command not found. If you're using Cloudflare URL, this is OK."
fi
echo ""

# Step 3: Test server connectivity
log "Step 3: Testing server connectivity..."
USE_TAILSCALE=false
USE_CLOUDFLARE=false

# Test Tailscale URL
if curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "$TAILSCALE_URL" > /dev/null 2>&1; then
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "$TAILSCALE_URL" 2>&1)
    if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "301" ] || [ "$HTTP_CODE" = "302" ] || [ "$HTTP_CODE" = "401" ] || [ "$HTTP_CODE" = "403" ]; then
        success "Tailscale URL is reachable: $TAILSCALE_URL"
        USE_TAILSCALE=true
    fi
fi

# Test Cloudflare URL
if curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "$CLOUDFLARE_URL" > /dev/null 2>&1; then
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "$CLOUDFLARE_URL" 2>&1)
    if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "301" ] || [ "$HTTP_CODE" = "302" ] || [ "$HTTP_CODE" = "401" ] || [ "$HTTP_CODE" = "403" ]; then
        success "Cloudflare URL is reachable: $CLOUDFLARE_URL"
        USE_CLOUDFLARE=true
    fi
fi

if [ "$USE_TAILSCALE" = false ] && [ "$USE_CLOUDFLARE" = false ]; then
    error "Neither server URL is reachable!"
    error "   Tailscale: $TAILSCALE_URL"
    error "   Cloudflare: $CLOUDFLARE_URL"
    error ""
    error "This indicates a network or server-side issue."
    error "Please check:"
    error "  1. Internet connectivity"
    error "  2. Tailscale status (if using Tailscale URL)"
    error "  3. Server status on motoko"
    exit 1
fi
echo ""

# Step 4: Ensure sync root exists
log "Step 4: Ensuring sync root directory exists..."
SYNC_ROOT="$HOME/nc"
if [ ! -d "$SYNC_ROOT" ]; then
    mkdir -p "$SYNC_ROOT"
    success "Created sync root: $SYNC_ROOT"
else
    success "Sync root exists: $SYNC_ROOT"
fi
echo ""

# Step 5: Restart Nextcloud
log "Step 5: Restarting Nextcloud..."
# Kill existing Nextcloud processes
pkill -f "Nextcloud" 2>/dev/null || true
sleep 2

# Launch Nextcloud
open -a Nextcloud
success "Nextcloud launched"
info "   Please wait a few seconds for Nextcloud to start..."
sleep 5
echo ""

# Step 6: Provide reconfiguration instructions
log "Step 6: Reconfiguration instructions"
echo ""
info "Nextcloud should now be running. To fix the connection:"
echo ""
info "1. Click the Nextcloud icon in your menu bar"
info "2. Click 'Settings' or the gear icon"
info "3. Click 'Account' tab"
info "4. If an account exists, click 'Remove account' or 'Log out'"
info "5. Click 'Add account' or 'Log in to your Nextcloud'"
echo ""

if [ "$USE_TAILSCALE" = true ]; then
    info "6. Enter server URL: ${GREEN}$TAILSCALE_URL${NC}"
    RECOMMENDED_URL="$TAILSCALE_URL"
elif [ "$USE_CLOUDFLARE" = true ]; then
    info "6. Enter server URL: ${GREEN}$CLOUDFLARE_URL${NC}"
    RECOMMENDED_URL="$CLOUDFLARE_URL"
else
    RECOMMENDED_URL="$CLOUDFLARE_URL"
    info "6. Enter server URL: ${GREEN}$CLOUDFLARE_URL${NC} (Cloudflare)"
fi

info "7. Authenticate via Entra ID (OIDC/SSO)"
info "8. Set sync root: ~/nc"
info "9. Select folders to sync: work, media, finance, inbox, assets, camera"
echo ""

# Alternative: Reset configuration files
info "Alternative: If the UI doesn't work, reset configuration:"
echo ""
warn "⚠️  This will remove your Nextcloud configuration (you'll need to reconfigure):"
read -p "   Do you want to reset Nextcloud configuration? (y/N): " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    log "Resetting Nextcloud configuration..."
    
    # Backup existing config
    BACKUP_DIR="$HOME/Library/Preferences/Nextcloud.backup.$(date +%Y%m%d-%H%M%S)"
    if [ -d "$HOME/Library/Preferences/Nextcloud" ]; then
        mkdir -p "$BACKUP_DIR"
        cp -r "$HOME/Library/Preferences/Nextcloud"/* "$BACKUP_DIR/" 2>/dev/null || true
        success "Backed up config to: $BACKUP_DIR"
    fi
    
    # Remove config files
    rm -rf "$HOME/Library/Preferences/Nextcloud/nextcloud.cfg" 2>/dev/null || true
    rm -rf "$HOME/Library/Application Support/Nextcloud/nextcloud.cfg" 2>/dev/null || true
    rm -rf "$HOME/Library/Caches/Nextcloud" 2>/dev/null || true
    
    success "Configuration reset complete"
    info "   Nextcloud will prompt for setup when you launch it"
    echo ""
    info "Launch Nextcloud setup wizard:"
    info "   open -a Nextcloud"
fi

echo ""
echo "=========================================="
success "Quick fix complete!"
echo "=========================================="
echo ""
info "If issues persist, run the diagnostic script:"
info "   ./scripts/diagnose-nextcloud-connection.sh"
echo ""

