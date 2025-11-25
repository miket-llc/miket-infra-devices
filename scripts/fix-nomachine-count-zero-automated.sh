#!/bin/bash
# Copyright (c) 2025 MikeT LLC. All rights reserved.
#
# Automated fix for NoMachine configuration on count-zero (macOS)
# Uses osascript to get admin privileges

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

# Create a temporary script that will be run with admin privileges
TEMP_SCRIPT=$(mktemp)
cat > "$TEMP_SCRIPT" << 'EOFSCRIPT'
#!/bin/bash
CONFIG_FILE="/Applications/NoMachine.app/Contents/Frameworks/etc/server.cfg"
BACKUP_FILE="${CONFIG_FILE}.backup.$(date +%Y%m%d-%H%M%S)"

# Create backup
cp "$CONFIG_FILE" "$BACKUP_FILE"

# Add settings if they don't exist
if ! grep -q "^EnableConsoleSessionSharing=" "$CONFIG_FILE" 2>/dev/null; then
    echo "EnableConsoleSessionSharing=1" >> "$CONFIG_FILE"
fi

if ! grep -q "^EnableSessionSharing=" "$CONFIG_FILE" 2>/dev/null; then
    echo "EnableSessionSharing=1" >> "$CONFIG_FILE"
fi

if ! grep -q "^EnableNXDisplayOutput=" "$CONFIG_FILE" 2>/dev/null; then
    echo "EnableNXDisplayOutput=1" >> "$CONFIG_FILE"
fi

if ! grep -q "^EnableNewSession=" "$CONFIG_FILE" 2>/dev/null; then
    echo "EnableNewSession=1" >> "$CONFIG_FILE"
fi

# Restart NoMachine server
/Applications/NoMachine.app/Contents/Frameworks/bin/nxserver --restart 2>&1 || {
    launchctl unload /Library/LaunchDaemons/com.nomachine.nxserver.plist 2>/dev/null || true
    launchctl load /Library/LaunchDaemons/com.nomachine.nxserver.plist 2>/dev/null || true
}

echo "Configuration updated successfully"
EOFSCRIPT

chmod +x "$TEMP_SCRIPT"

# Use osascript to run with admin privileges
echo "Requesting admin privileges to update NoMachine configuration..."
osascript <<EOF
do shell script "bash '$TEMP_SCRIPT'" with administrator privileges
EOF

# Clean up
rm -f "$TEMP_SCRIPT"

# Wait a moment for server to start
sleep 3

# Check server status
echo ""
echo "=== NoMachine Server Status ==="
/Applications/NoMachine.app/Contents/Frameworks/bin/nxserver --status 2>&1 | head -20

# Verify settings were added
echo ""
echo "=== Verifying Configuration ==="
grep -E "^Enable(ConsoleSessionSharing|SessionSharing|NXDisplayOutput|NewSession)=" "$CONFIG_FILE" || echo "WARNING: Some settings not found"

echo ""
echo "=== Configuration Fix Complete ==="
echo ""
echo "Next steps:"
echo "1. Verify Screen Recording permission is granted in System Preferences"
echo "2. Test connection from remote client"
echo "3. Try both 'Console Session' and 'New Session' options"


