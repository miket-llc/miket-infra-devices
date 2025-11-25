#!/bin/bash
# Copyright (c) 2025 MikeT LLC. All rights reserved.
#
# Fix NoMachine configuration on count-zero (macOS)
# Adds required settings for console session sharing and UI rendering

set -euo pipefail

CONFIG_FILE="/Applications/NoMachine.app/Contents/Frameworks/etc/server.cfg"
BACKUP_FILE="${CONFIG_FILE}.backup.$(date +%Y%m%d-%H%M%S)"

echo "=== Fixing NoMachine Configuration on count-zero ==="
echo ""

# Check if config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo "ERROR: Config file not found: $CONFIG_FILE"
    exit 1
fi

# Create backup
echo "Creating backup: $BACKUP_FILE"
sudo cp "$CONFIG_FILE" "$BACKUP_FILE"

# Check if settings already exist
if grep -q "^EnableConsoleSessionSharing=" "$CONFIG_FILE" 2>/dev/null; then
    echo "EnableConsoleSessionSharing already configured"
else
    echo "Adding EnableConsoleSessionSharing=1"
    echo "EnableConsoleSessionSharing=1" | sudo tee -a "$CONFIG_FILE" > /dev/null
fi

if grep -q "^EnableSessionSharing=" "$CONFIG_FILE" 2>/dev/null; then
    echo "EnableSessionSharing already configured"
else
    echo "Adding EnableSessionSharing=1"
    echo "EnableSessionSharing=1" | sudo tee -a "$CONFIG_FILE" > /dev/null
fi

if grep -q "^EnableNXDisplayOutput=" "$CONFIG_FILE" 2>/dev/null; then
    echo "EnableNXDisplayOutput already configured"
else
    echo "Adding EnableNXDisplayOutput=1"
    echo "EnableNXDisplayOutput=1" | sudo tee -a "$CONFIG_FILE" > /dev/null
fi

if grep -q "^EnableNewSession=" "$CONFIG_FILE" 2>/dev/null; then
    echo "EnableNewSession already configured"
else
    echo "Adding EnableNewSession=1"
    echo "EnableNewSession=1" | sudo tee -a "$CONFIG_FILE" > /dev/null
fi

# Verify settings were added
echo ""
echo "=== Verifying Configuration ==="
grep -E "^Enable(ConsoleSessionSharing|SessionSharing|NXDisplayOutput|NewSession)=" "$CONFIG_FILE" || echo "WARNING: Some settings not found"

# Restart NoMachine server
echo ""
echo "=== Restarting NoMachine Server ==="
sudo /Applications/NoMachine.app/Contents/Frameworks/bin/nxserver --restart || {
    echo "WARNING: Restart command failed, trying alternative method"
    sudo launchctl unload /Library/LaunchDaemons/com.nomachine.nxserver.plist 2>/dev/null || true
    sudo launchctl load /Library/LaunchDaemons/com.nomachine.nxserver.plist 2>/dev/null || true
}

# Wait a moment for server to start
sleep 3

# Check server status
echo ""
echo "=== NoMachine Server Status ==="
/Applications/NoMachine.app/Contents/Frameworks/bin/nxserver --status 2>&1 | head -20

echo ""
echo "=== Configuration Fix Complete ==="
echo "Backup saved to: $BACKUP_FILE"
echo ""
echo "Next steps:"
echo "1. Verify Screen Recording permission is granted in System Preferences"
echo "2. Test connection from remote client"
echo "3. Try both 'Console Session' and 'New Session' options"

