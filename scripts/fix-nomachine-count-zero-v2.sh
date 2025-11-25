#!/bin/bash
# Copyright (c) 2025 MikeT LLC. All rights reserved.
#
# Automated fix for NoMachine configuration on count-zero (macOS)
# Uses osascript to get admin privileges

set -euo pipefail

CONFIG_FILE="/Applications/NoMachine.app/Contents/Frameworks/etc/server.cfg"

echo "=== Fixing NoMachine Configuration on count-zero ==="
echo ""

# Check if config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo "ERROR: Config file not found: $CONFIG_FILE"
    exit 1
fi

# Use osascript to add settings with admin privileges
echo "Requesting admin privileges to update NoMachine configuration..."

osascript <<EOF
do shell script "
# Create backup
cp '$CONFIG_FILE' '${CONFIG_FILE}.backup.\$(date +%Y%m%d-%H%M%S)'

# Add settings if they don't exist using tee
if ! grep -q '^EnableConsoleSessionSharing=' '$CONFIG_FILE' 2>/dev/null; then
    echo 'EnableConsoleSessionSharing=1' | tee -a '$CONFIG_FILE' > /dev/null
fi

if ! grep -q '^EnableSessionSharing=' '$CONFIG_FILE' 2>/dev/null; then
    echo 'EnableSessionSharing=1' | tee -a '$CONFIG_FILE' > /dev/null
fi

if ! grep -q '^EnableNXDisplayOutput=' '$CONFIG_FILE' 2>/dev/null; then
    echo 'EnableNXDisplayOutput=1' | tee -a '$CONFIG_FILE' > /dev/null
fi

if ! grep -q '^EnableNewSession=' '$CONFIG_FILE' 2>/dev/null; then
    echo 'EnableNewSession=1' | tee -a '$CONFIG_FILE' > /dev/null
fi

# Verify settings were added
echo '=== Verifying Configuration ==='
grep -E '^Enable(ConsoleSessionSharing|SessionSharing|NXDisplayOutput|NewSession)=' '$CONFIG_FILE' || echo 'WARNING: Some settings not found'

# Restart NoMachine server
echo ''
echo '=== Restarting NoMachine Server ==='
/Applications/NoMachine.app/Contents/Frameworks/bin/nxserver --restart 2>&1 || {
    launchctl unload /Library/LaunchDaemons/com.nomachine.nxserver.plist 2>/dev/null || true
    sleep 2
    launchctl load /Library/LaunchDaemons/com.nomachine.nxserver.plist 2>/dev/null || true
}

sleep 3

# Check server status
echo ''
echo '=== NoMachine Server Status ==='
/Applications/NoMachine.app/Contents/Frameworks/bin/nxserver --status 2>&1 | head -20
" with administrator privileges
EOF

echo ""
echo "=== Configuration Fix Complete ==="
echo ""
echo "Next steps:"
echo "1. Verify Screen Recording permission is granted in System Preferences"
echo "2. Test connection from remote client"
echo "3. Try both 'Console Session' and 'New Session' options"

