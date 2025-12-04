#!/bin/bash
# Copyright (c) 2025 MikeT LLC. All rights reserved.
#
# diagnose-timemachine-smb.sh
# Diagnose Time Machine SMB connection issues on macOS
# Run this ON count-zero as the user experiencing the issue

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

SMB_SERVER="motoko"
SMB_SERVER_FQDN="motoko.pangolin-vega.ts.net"
SMB_SHARE="time"
SMB_USER="mdt"
SECRETS_FILE="${HOME}/.mkt/mounts.env"

echo "=========================================="
echo "Time Machine SMB Diagnostic"
echo "=========================================="
echo ""

# 1. Check Time Machine status
log "1. Checking Time Machine status..."
TM_STATUS=$(tmutil status 2>&1 || echo "ERROR")
if echo "$TM_STATUS" | grep -q "Running = 1"; then
    warn "Time Machine backup is currently running"
    echo "$TM_STATUS" | grep -E "(BackupPhase|Percent|Running)" | sed 's/^/   /'
elif echo "$TM_STATUS" | grep -q "Running = 0"; then
    success "Time Machine is idle"
else
    error "Could not determine Time Machine status"
fi
echo ""

# 2. Check Time Machine destinations
log "2. Checking Time Machine destinations..."
TM_DEST=$(tmutil destinationinfo 2>&1 || echo "ERROR")
if echo "$TM_DEST" | grep -q "smb://"; then
    success "Time Machine destination configured"
    echo "$TM_DEST" | grep -E "(Name|URL|ID)" | sed 's/^/   /'
else
    error "No Time Machine destination found"
fi
echo ""

# 3. Check network connectivity
log "3. Checking network connectivity..."
if ping -c 2 "$SMB_SERVER" &>/dev/null; then
    success "Can ping $SMB_SERVER (short hostname)"
else
    error "Cannot ping $SMB_SERVER (short hostname)"
fi

if ping -c 2 "$SMB_SERVER_FQDN" &>/dev/null; then
    success "Can ping $SMB_SERVER_FQDN (FQDN)"
else
    error "Cannot ping $SMB_SERVER_FQDN (FQDN)"
fi
echo ""

# 4. Check SMB mount status
log "4. Checking SMB mount status..."
TIME_MOUNT="${HOME}/.mkt/time"
if mount | grep -q "on ${TIME_MOUNT} "; then
    success "Time share is mounted at ${TIME_MOUNT}"
    MOUNT_INFO=$(mount | grep "on ${TIME_MOUNT} ")
    echo "   $MOUNT_INFO"
    
    # Test if mount is accessible
    if ls "$TIME_MOUNT" >/dev/null 2>&1; then
        success "Time mount is accessible"
    else
        error "Time mount is stale (not accessible)"
        warn "Run: umount $TIME_MOUNT && ~/.scripts/mount_shares.sh"
    fi
else
    warn "Time share is not mounted at ${TIME_MOUNT}"
fi
echo ""

# 5. Check Time Machine mount
log "5. Checking Time Machine-specific mount..."
TM_MOUNT=$(mount | grep -i "timemachine.*motoko" || echo "")
if [ -n "$TM_MOUNT" ]; then
    success "Time Machine has its own mount"
    echo "$TM_MOUNT" | sed 's/^/   /'
    
    # Extract mount point
    TM_MOUNT_POINT=$(echo "$TM_MOUNT" | awk '{print $3}')
    if [ -n "$TM_MOUNT_POINT" ] && [ -d "$TM_MOUNT_POINT" ]; then
        if ls "$TM_MOUNT_POINT" >/dev/null 2>&1; then
            success "Time Machine mount is accessible"
        else
            error "Time Machine mount is stale"
        fi
    fi
else
    warn "No Time Machine-specific mount found"
fi
echo ""

# 6. Check SMB credentials
log "6. Checking SMB credentials..."
if [ -f "$SECRETS_FILE" ]; then
    success "Secrets file exists: $SECRETS_FILE"
    if grep -q "^SMB_PASSWORD=" "$SECRETS_FILE"; then
        success "SMB_PASSWORD is set"
    else
        error "SMB_PASSWORD not found in secrets file"
    fi
else
    error "Secrets file missing: $SECRETS_FILE"
    warn "Run: ansible-playbook -i inventory/hosts.yml playbooks/secrets-sync.yml --limit count-zero"
fi
echo ""

# 7. Check Keychain for Time Machine credentials
log "7. Checking macOS Keychain for Time Machine credentials..."
KEYCHAIN_ITEMS=$(security find-internet-password -s "$SMB_SERVER_FQDN" -a "$SMB_USER" 2>&1 || echo "NOT_FOUND")
if echo "$KEYCHAIN_ITEMS" | grep -q "keychain:"; then
    success "Time Machine credentials found in Keychain"
else
    warn "Time Machine credentials not found in Keychain"
    warn "Time Machine may prompt for password on next backup"
fi
echo ""

# 8. Test SMB connectivity
log "8. Testing SMB connectivity..."
if command -v smbclient &>/dev/null; then
    if [ -f "$SECRETS_FILE" ]; then
        source "$SECRETS_FILE"
        if smbclient -L "//${SMB_SERVER_FQDN}/${SMB_SHARE}" -U "${SMB_USER}%${SMB_PASSWORD}" -N 2>&1 | head -5 &>/dev/null; then
            success "SMB connection test successful (FQDN)"
        else
            error "SMB connection test failed (FQDN)"
        fi
    else
        warn "Cannot test SMB - secrets file missing"
    fi
else
    warn "smbclient not installed (optional for testing)"
fi
echo ""

# 9. Check recent Time Machine errors
log "9. Checking recent Time Machine errors..."
RECENT_ERRORS=$(log show --predicate 'subsystem == "com.apple.backupd"' --last 1h --style compact 2>&1 | grep -i "error\|fail" | tail -10 || echo "")
if [ -n "$RECENT_ERRORS" ]; then
    warn "Recent Time Machine errors found:"
    echo "$RECENT_ERRORS" | sed 's/^/   /'
else
    success "No recent Time Machine errors found"
fi
echo ""

# Summary and recommendations
echo "=========================================="
echo "Summary and Recommendations"
echo "=========================================="
echo ""

# Check if Time Machine mount is working
TM_MOUNT_WORKING="no"
if mount | grep -qi "timemachine.*motoko"; then
    TM_MOUNT_POINT=$(mount | grep -i "timemachine.*motoko" | awk '{print $3}')
    if [ -n "$TM_MOUNT_POINT" ] && ls "$TM_MOUNT_POINT" >/dev/null 2>&1; then
        TM_MOUNT_WORKING="yes"
    fi
fi

if [ "$TM_MOUNT_WORKING" == "yes" ]; then
    success "Time Machine mount appears to be working"
    echo ""
    echo "If Time Machine is still failing, try:"
    echo "  1. Check Time Machine preferences: System Settings > Time Machine"
    echo "  2. Remove and re-add Time Machine destination"
    echo "  3. Check server-side SMB logs: tailscale ssh motoko 'tail -50 /var/log/samba/log.smbd'"
else
    error "Time Machine mount is not working"
    echo ""
    echo "Try these fixes:"
    echo "  1. Ensure regular mounts are working:"
    echo "     ~/.scripts/mount_shares.sh"
    echo ""
    echo "  2. Remove and re-add Time Machine destination:"
    echo "     tmutil removedestination <ID>"
    echo "     # Then add via System Settings > Time Machine"
    echo ""
    echo "  3. Ensure SMB credentials are in Keychain:"
    echo "     # Time Machine will prompt for password on next backup"
    echo "     # Enter credentials when prompted"
fi

echo ""
log "Diagnostic complete"

