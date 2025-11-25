#!/bin/bash
# Copyright (c) 2025 MikeT LLC. All rights reserved.
#
# Manual NoMachine Configuration Fix for count-zero (macOS)
# This script MUST be run with sudo/admin privileges
# macOS System Integrity Protection requires admin privileges to modify protected files

set -euo pipefail

CONFIG_FILE="/Applications/NoMachine.app/Contents/Frameworks/etc/server.cfg"

if [ "$EUID" -ne 0 ]; then
    echo "ERROR: This script must be run with sudo/admin privileges"
    echo ""
    echo "Run: sudo $0"
    echo ""
    echo "Or use this one-liner:"
    echo "sudo sh -c 'cat >> $CONFIG_FILE << \"EOF\""
    echo ""
    echo "# NoMachine UI rendering settings"
    echo "EnableConsoleSessionSharing=1"
    echo "EnableSessionSharing=1"
    echo "EnableNXDisplayOutput=1"
    echo "EnableNewSession=1"
    echo "EOF"
    echo "'"
    exit 1
fi

echo "=== NoMachine Configuration Fix ==="
echo ""

# Create backup
BACKUP_FILE="${CONFIG_FILE}.backup.$(date +%Y%m%d-%H%M%S)"
echo "Creating backup: $BACKUP_FILE"
cp "$CONFIG_FILE" "$BACKUP_FILE"

# Check if settings already exist
if grep -q "^EnableConsoleSessionSharing=" "$CONFIG_FILE" 2>/dev/null; then
    echo "⚠️  Settings already exist - skipping"
else
    echo "Adding configuration settings..."
    cat >> "$CONFIG_FILE" << 'EOF'

# NoMachine UI rendering settings - added by fix script
EnableConsoleSessionSharing=1
EnableSessionSharing=1
EnableNXDisplayOutput=1
EnableNewSession=1
EOF
    echo "✅ Settings added"
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
/Applications/NoMachine.app/Contents/Frameworks/bin/nxserver --status 2>&1 | head -10

# Check port
echo ""
echo "=== Port Status ==="
if lsof -i :4000 &>/dev/null; then
    echo "✅ Port 4000 is listening"
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


