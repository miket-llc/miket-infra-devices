#!/bin/bash
# Copyright (c) 2025 MikeT LLC. All rights reserved.
#
# diagnose-nextcloud-connection.sh
# Diagnose Nextcloud client connection issues on macOS
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
echo "Nextcloud Connection Diagnostic"
echo "=========================================="
echo ""

# Track issues found
ISSUES_FOUND=0

# 1. Check if Nextcloud app is installed
log "1. Checking Nextcloud app installation..."
if [ -d "/Applications/Nextcloud.app" ]; then
    success "Nextcloud.app is installed"
    APP_VERSION=$(defaults read /Applications/Nextcloud.app/Contents/Info.plist CFBundleShortVersionString 2>/dev/null || echo "unknown")
    info "   Version: $APP_VERSION"
else
    error "Nextcloud.app is NOT installed"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
fi
echo ""

# 2. Check if Nextcloud process is running
log "2. Checking Nextcloud process status..."
if pgrep -f "Nextcloud" > /dev/null 2>&1; then
    success "Nextcloud process is running"
    ps aux | grep -i nextcloud | grep -v grep | grep -v "diagnose-nextcloud" | head -3 | sed 's/^/   /'
else
    error "Nextcloud process is NOT running"
    warn "   Launch Nextcloud: open -a Nextcloud"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
fi
echo ""

# 3. Check Nextcloud configuration
log "3. Checking Nextcloud configuration..."
CONFIG_DIR="$HOME/Library/Preferences/Nextcloud"
if [ -d "$CONFIG_DIR" ]; then
    success "Config directory exists: $CONFIG_DIR"
    
    # Check for config file
    if [ -f "$CONFIG_DIR/nextcloud.cfg" ]; then
        success "   Config file found: nextcloud.cfg"
        
        # Try to extract server URL (if readable)
        if grep -q "url" "$CONFIG_DIR/nextcloud.cfg" 2>/dev/null; then
            CONFIG_URL=$(grep -i "url" "$CONFIG_DIR/nextcloud.cfg" | head -1 | sed 's/.*=//' | tr -d ' ' || echo "unknown")
            info "   Configured URL: $CONFIG_URL"
        fi
    else
        warn "   Config file not found (may be in Application Support)"
    fi
    
    # Check Application Support directory
    APP_SUPPORT_DIR="$HOME/Library/Application Support/Nextcloud"
    if [ -d "$APP_SUPPORT_DIR" ]; then
        success "   Application Support directory exists"
    fi
else
    error "Config directory NOT found: $CONFIG_DIR"
    warn "   Nextcloud may not be configured yet"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
fi
echo ""

# 4. Check sync root directory
log "4. Checking sync root directory..."
SYNC_ROOT="$HOME/nc"
if [ -d "$SYNC_ROOT" ]; then
    success "Sync root exists: $SYNC_ROOT"
    ls -ld "$SYNC_ROOT" | sed 's/^/   /'
else
    warn "Sync root NOT found: $SYNC_ROOT"
    info "   This is normal if Nextcloud hasn't been configured yet"
fi
echo ""

# 5. Check Tailscale connectivity
log "5. Checking Tailscale connectivity..."
if command -v tailscale > /dev/null 2>&1; then
    TAILSCALE_STATUS=$(tailscale status 2>&1 || echo "ERROR")
    if echo "$TAILSCALE_STATUS" | grep -q "online\|connected" || tailscale status 2>/dev/null | grep -q "100\."; then
        success "Tailscale is connected"
        tailscale status 2>/dev/null | head -3 | sed 's/^/   /' || true
    else
        error "Tailscale is NOT connected"
        warn "   Start Tailscale: sudo launchctl load /Library/LaunchDaemons/com.tailscale.tailscaled.plist"
        warn "   Or check Tailscale menu bar icon"
        ISSUES_FOUND=$((ISSUES_FOUND + 1))
    fi
else
    warn "Tailscale command not found (may not be installed)"
fi
echo ""

# 6. Test DNS resolution
log "6. Testing DNS resolution..."
if host motoko.pangolin-vega.ts.net > /dev/null 2>&1; then
    success "DNS resolves: motoko.pangolin-vega.ts.net"
    DNS_RESULT=$(host motoko.pangolin-vega.ts.net 2>&1 | grep "has address" | head -1 || echo "")
    if [ -n "$DNS_RESULT" ]; then
        info "   $DNS_RESULT"
    fi
else
    error "DNS resolution FAILED: motoko.pangolin-vega.ts.net"
    warn "   This may indicate Tailscale DNS (MagicDNS) is not working"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
fi

if host nextcloud.miket.io > /dev/null 2>&1; then
    success "DNS resolves: nextcloud.miket.io"
    DNS_RESULT=$(host nextcloud.miket.io 2>&1 | grep "has address" | head -1 || echo "")
    if [ -n "$DNS_RESULT" ]; then
        info "   $DNS_RESULT"
    fi
else
    warn "DNS resolution FAILED: nextcloud.miket.io"
    warn "   This may indicate general DNS issues"
fi
echo ""

# 7. Test server connectivity (Tailscale)
log "7. Testing Tailscale server connectivity..."
if curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "$TAILSCALE_URL" > /dev/null 2>&1; then
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "$TAILSCALE_URL" 2>&1)
    if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "301" ] || [ "$HTTP_CODE" = "302" ] || [ "$HTTP_CODE" = "401" ] || [ "$HTTP_CODE" = "403" ]; then
        success "Tailscale URL is reachable: $TAILSCALE_URL (HTTP $HTTP_CODE)"
    else
        warn "Tailscale URL returned HTTP $HTTP_CODE: $TAILSCALE_URL"
        info "   This may indicate server-side issues"
    fi
else
    error "Tailscale URL is NOT reachable: $TAILSCALE_URL"
    warn "   Check Tailscale connectivity and DNS"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
fi
echo ""

# 8. Test server connectivity (Cloudflare)
log "8. Testing Cloudflare server connectivity..."
if curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "$CLOUDFLARE_URL" > /dev/null 2>&1; then
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "$CLOUDFLARE_URL" 2>&1)
    if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "301" ] || [ "$HTTP_CODE" = "302" ] || [ "$HTTP_CODE" = "401" ] || [ "$HTTP_CODE" = "403" ]; then
        success "Cloudflare URL is reachable: $CLOUDFLARE_URL (HTTP $HTTP_CODE)"
    else
        warn "Cloudflare URL returned HTTP $HTTP_CODE: $CLOUDFLARE_URL"
        info "   This may indicate Cloudflare Access or server-side issues"
    fi
else
    error "Cloudflare URL is NOT reachable: $CLOUDFLARE_URL"
    warn "   Check internet connectivity and Cloudflare tunnel status"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
fi
echo ""

# 9. Check Nextcloud logs
log "9. Checking Nextcloud logs..."
LOG_DIR="$HOME/Library/Logs/Nextcloud"
if [ -d "$LOG_DIR" ]; then
    LOG_FILES=$(find "$LOG_DIR" -name "*.log" -type f 2>/dev/null | head -5)
    if [ -n "$LOG_FILES" ]; then
        success "Found log files in $LOG_DIR"
        echo "$LOG_FILES" | while read -r logfile; do
            if [ -f "$logfile" ]; then
                info "   $(basename "$logfile")"
                # Check for recent errors
                RECENT_ERRORS=$(tail -20 "$logfile" 2>/dev/null | grep -i "error\|fail\|disconnect" | tail -3 || true)
                if [ -n "$RECENT_ERRORS" ]; then
                    echo "$RECENT_ERRORS" | sed 's/^/      ERROR: /'
                fi
            fi
        done
    else
        info "   No log files found"
    fi
else
    info "   Log directory not found (may not have logged yet)"
fi
echo ""

# 10. Check for common configuration issues
log "10. Checking for common configuration issues..."
if [ -f "$CONFIG_DIR/nextcloud.cfg" ]; then
    # Check if URL is configured correctly
    if grep -q "nextcloud.miket.io\|motoko.pangolin-vega.ts.net" "$CONFIG_DIR/nextcloud.cfg" 2>/dev/null; then
        success "   Server URL appears to be configured"
    else
        warn "   Server URL may not be configured correctly"
    fi
fi
echo ""

# Summary and recommendations
echo "=========================================="
echo "Diagnostic Summary"
echo "=========================================="
echo ""

if [ $ISSUES_FOUND -eq 0 ]; then
    success "No critical issues found!"
    info ""
    info "If Nextcloud still shows connection errors, try:"
    info "1. Click the Nextcloud menu bar icon"
    info "2. Click 'Settings' or 'Account settings'"
    info "3. Log out and log back in"
    info "4. Use URL: $TAILSCALE_URL (if on Tailscale) or $CLOUDFLARE_URL"
else
    error "Found $ISSUES_FOUND critical issue(s)"
    echo ""
    info "Recommended actions:"
    echo ""
    
    if [ ! -d "/Applications/Nextcloud.app" ]; then
        info "1. Install Nextcloud:"
        info "   brew install --cask nextcloud"
        echo ""
    fi
    
    if ! pgrep -f "Nextcloud" > /dev/null 2>&1; then
        info "2. Launch Nextcloud:"
        info "   open -a Nextcloud"
        echo ""
    fi
    
    if ! tailscale status 2>/dev/null | grep -q "100\."; then
        info "3. Fix Tailscale connectivity:"
        info "   - Check Tailscale menu bar icon"
        info "   - Restart Tailscale: sudo launchctl unload /Library/LaunchDaemons/com.tailscale.tailscaled.plist"
        info "   - Then: sudo launchctl load /Library/LaunchDaemons/com.tailscale.tailscaled.plist"
        echo ""
    fi
    
    if ! curl -s -o /dev/null --connect-timeout 5 "$TAILSCALE_URL" > /dev/null 2>&1 && \
       ! curl -s -o /dev/null --connect-timeout 5 "$CLOUDFLARE_URL" > /dev/null 2>&1; then
        info "4. Reconfigure Nextcloud connection:"
        info "   - Open Nextcloud app"
        info "   - Remove existing account"
        info "   - Add new account with URL: $TAILSCALE_URL (Tailscale) or $CLOUDFLARE_URL (Cloudflare)"
        echo ""
    fi
fi

echo ""
info "For more detailed troubleshooting, see:"
info "  docs/runbooks/troubleshoot-count-zero-nextcloud.md"
echo ""
echo "=========================================="

