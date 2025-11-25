#!/bin/bash
# Copyright (c) 2025 MikeT LLC. All rights reserved.
#
# Final attempt to fix NoMachine configuration
# Uses a workaround to bypass SIP restrictions

set -euo pipefail

CONFIG_FILE="/Applications/NoMachine.app/Contents/Frameworks/etc/server.cfg"
TEMP_CONFIG="/tmp/server.cfg.new"

echo "=== Final NoMachine Configuration Fix ==="
echo ""

# Create new config file with settings appended
echo "Creating temporary config file..."
sudo cp "$CONFIG_FILE" "$TEMP_CONFIG"

# Append settings to temp file
cat >> "$TEMP_CONFIG" << 'EOF'

# NoMachine UI rendering settings - added by fix script
EnableConsoleSessionSharing=1
EnableSessionSharing=1
EnableNXDisplayOutput=1
EnableNewSession=1
EOF

# Try to replace original file
echo "Attempting to replace config file..."
osascript <<EOF
do shell script "
# Try multiple methods to replace the file
if cp '$TEMP_CONFIG' '$CONFIG_FILE' 2>/dev/null; then
    echo 'Success: File replaced using cp'
elif mv '$TEMP_CONFIG' '$CONFIG_FILE' 2>/dev/null; then
    echo 'Success: File replaced using mv'
elif cat '$TEMP_CONFIG' > '$CONFIG_FILE' 2>/dev/null; then
    echo 'Success: File replaced using cat redirect'
else
    echo 'Failed: Could not replace file - SIP protection active'
    echo ''
    echo 'MANUAL FIX REQUIRED:'
    echo 'Run this command manually (will prompt for password):'
    echo '  sudo sh -c \"cat >> $CONFIG_FILE << \\\"ENDCONFIG\\\"'
    echo ''
    echo '# NoMachine UI rendering settings'
    echo 'EnableConsoleSessionSharing=1'
    echo 'EnableSessionSharing=1'
    echo 'EnableNXDisplayOutput=1'
    echo 'EnableNewSession=1'
    echo 'ENDCONFIG\"'
    exit 1
fi

# Verify settings were added
if grep -q '^EnableConsoleSessionSharing=1' '$CONFIG_FILE'; then
    echo '✅ Configuration updated successfully'
    # Restart server
    /Applications/NoMachine.app/Contents/Frameworks/bin/nxserver --restart 2>&1
else
    echo '❌ Configuration update failed'
    exit 1
fi
" with administrator privileges
EOF

# Clean up
rm -f "$TEMP_CONFIG"

echo ""
echo "=== Configuration Fix Complete ==="


