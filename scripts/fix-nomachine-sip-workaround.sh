#!/bin/bash
# Copyright (c) 2025 MikeT LLC. All rights reserved.
#
# NoMachine Configuration Fix - SIP Workaround
# This script must be run with admin privileges to work around macOS SIP

set -euo pipefail

CONFIG_FILE="/Applications/NoMachine.app/Contents/Frameworks/etc/server.cfg"

echo "=== NoMachine Configuration Fix (SIP Workaround) ==="
echo ""
echo "This script requires admin privileges to modify the NoMachine config file."
echo "macOS System Integrity Protection prevents normal file editing."
echo ""

# Check if running with admin privileges
if [ "$EUID" -ne 0 ]; then
    echo "This script must be run with admin privileges."
    echo "Please run: sudo $0"
    echo ""
    echo "Or use this one-liner:"
    echo "sudo sh -c 'echo \"\" >> $CONFIG_FILE && echo \"# NoMachine UI rendering settings\" >> $CONFIG_FILE && echo \"EnableConsoleSessionSharing=1\" >> $CONFIG_FILE && echo \"EnableSessionSharing=1\" >> $CONFIG_FILE && echo \"EnableNXDisplayOutput=1\" >> $CONFIG_FILE && echo \"EnableNewSession=1\" >> $CONFIG_FILE && /Applications/NoMachine.app/Contents/Frameworks/bin/nxserver --restart'"
    exit 1
fi

# Create backup
BACKUP_FILE="${CONFIG_FILE}.backup.$(date +%Y%m%d-%H%M%S)"
echo "Creating backup: $BACKUP_FILE"
cp "$CONFIG_FILE" "$BACKUP_FILE"

# Add settings if they don't exist
echo "Adding configuration settings..."
if ! grep -q "^EnableConsoleSessionSharing=" "$CONFIG_FILE" 2>/dev/null; then
    echo "" >> "$CONFIG_FILE"
    echo "# NoMachine UI rendering settings - added $(date)" >> "$CONFIG_FILE"
    echo "EnableConsoleSessionSharing=1" >> "$CONFIG_FILE"
    echo "EnableSessionSharing=1" >> "$CONFIG_FILE"
    echo "EnableNXDisplayOutput=1" >> "$CONFIG_FILE"
    echo "EnableNewSession=1" >> "$CONFIG_FILE"
    echo "✅ Settings added"
else
    echo "⚠️  Settings already exist"
fi

# Verify settings
echo ""
echo "=== Verifying Configuration ==="
grep -E "^Enable(ConsoleSessionSharing|SessionSharing|NXDisplayOutput|NewSession)=" "$CONFIG_FILE" || echo "❌ Settings not found"

# Restart NoMachine server
echo ""
echo "=== Restarting NoMachine Server ==="
/Applications/NoMachine.app/Contents/Frameworks/bin/nxserver --restart 2>&1

sleep 3

# Check server status
echo ""
echo "=== NoMachine Server Status ==="
/Applications/NoMachine.app/Contents/Frameworks/bin/nxserver --status 2>&1 | head -20

# Check port
echo ""
echo "=== Port Status ==="
if lsof -i :4000 &>/dev/null; then
    echo "✅ Port 4000 is listening"
    lsof -i :4000 | head -3
else
    echo "❌ Port 4000 is not listening"
fi

echo ""
echo "=== Configuration Fix Complete ==="
echo "Backup saved to: $BACKUP_FILE"
echo ""
echo "Next steps:"
echo "1. Verify Screen Recording permission in System Preferences > Security & Privacy > Privacy > Screen Recording"
echo "2. Test connection from remote client"
echo "3. Try both 'Console Session' and 'New Session' options"

