#!/bin/bash
# Copyright (c) 2025 MikeT LLC. All rights reserved.
#
# Comprehensive NoMachine diagnostic and fix script for count-zero (macOS)
# Diagnoses issues and provides automated fixes where possible

set -euo pipefail

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  NoMachine Diagnostic and Fix Script for count-zero (macOS) ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Step 1: Check NoMachine server status
echo "=== Step 1: NoMachine Server Status ==="
if /Applications/NoMachine.app/Contents/Frameworks/bin/nxserver --status &>/dev/null; then
    echo "✅ NoMachine server is running"
    /Applications/NoMachine.app/Contents/Frameworks/bin/nxserver --status 2>&1 | head -5
else
    echo "❌ NoMachine server is not running"
    echo "Attempting to start..."
    osascript <<'EOF' 2>/dev/null || true
do shell script "/Applications/NoMachine.app/Contents/Frameworks/bin/nxserver --start" with administrator privileges
EOF
fi

# Step 2: Check port 4000
echo ""
echo "=== Step 2: Port 4000 Status ==="
if lsof -i :4000 &>/dev/null; then
    echo "✅ Port 4000 is listening"
    lsof -i :4000 | head -3
else
    echo "❌ Port 4000 is not listening"
fi

# Step 3: Check configuration
echo ""
echo "=== Step 3: Configuration Check ==="
CONFIG_FILE="/Applications/NoMachine.app/Contents/Frameworks/etc/server.cfg"
REQUIRED_SETTINGS=("EnableConsoleSessionSharing=1" "EnableSessionSharing=1" "EnableNXDisplayOutput=1" "EnableNewSession=1")
MISSING_SETTINGS=()

for setting in "${REQUIRED_SETTINGS[@]}"; do
    if ! grep -q "^${setting}" "$CONFIG_FILE" 2>/dev/null; then
        MISSING_SETTINGS+=("$setting")
        echo "❌ Missing: $setting"
    else
        echo "✅ Found: $setting"
    fi
done

# Step 4: Check screen recording permissions (can't verify programmatically, but provide instructions)
echo ""
echo "=== Step 4: Screen Recording Permission Check ==="
echo "⚠️  Screen Recording permission cannot be verified programmatically"
echo "Please verify manually:"
echo "  1. Open System Preferences"
echo "  2. Go to Security & Privacy > Privacy"
echo "  3. Select Screen Recording from the left sidebar"
echo "  4. Ensure NoMachine is listed and checked"
echo "  5. If not listed, click + and add: /Applications/NoMachine.app"
echo ""

# Step 5: Attempt to fix configuration
if [ ${#MISSING_SETTINGS[@]} -gt 0 ]; then
    echo "=== Step 5: Configuration Fix Attempt ==="
    echo "Missing settings detected. Attempting to add them..."
    echo ""
    echo "⚠️  macOS System Integrity Protection (SIP) may prevent automatic configuration."
    echo "If automatic fix fails, run this command manually:"
    echo ""
    echo "sudo sh -c 'cat >> $CONFIG_FILE << \"EOF\""
    echo ""
    echo "# NoMachine UI rendering settings"
    echo "EnableConsoleSessionSharing=1"
    echo "EnableSessionSharing=1"
    echo "EnableNXDisplayOutput=1"
    echo "EnableNewSession=1"
    echo "EOF"
    echo "'"
    echo ""
    
    # Try to add settings using osascript with admin privileges
    CONFIG_RESULT=$(osascript <<'EOF' 2>&1
do shell script "
echo '' >> '$CONFIG_FILE' && \
echo '# NoMachine UI rendering settings - added $(date)' >> '$CONFIG_FILE' && \
echo 'EnableConsoleSessionSharing=1' >> '$CONFIG_FILE' && \
echo 'EnableSessionSharing=1' >> '$CONFIG_FILE' && \
echo 'EnableNXDisplayOutput=1' >> '$CONFIG_FILE' && \
echo 'EnableNewSession=1' >> '$CONFIG_FILE'
" with administrator privileges
EOF
)
    
    if [ $? -ne 0 ]; then
        echo "❌ Automatic configuration failed due to SIP protection"
        echo "Please run the manual command shown above"
    fi
    
    # Verify settings were added
    sleep 1
    if grep -q "^EnableConsoleSessionSharing=1" "$CONFIG_FILE" 2>/dev/null; then
        echo "✅ Configuration updated successfully"
        echo "Restarting NoMachine server..."
        osascript <<'EOF' 2>/dev/null || true
do shell script "/Applications/NoMachine.app/Contents/Frameworks/bin/nxserver --restart" with administrator privileges
EOF
        sleep 3
    else
        echo "❌ Configuration update failed - SIP protection active"
        echo "Manual intervention required (see command above)"
    fi
else
    echo "✅ All required settings are present"
fi

# Step 6: Final status check
echo ""
echo "=== Step 6: Final Status Check ==="
echo "Server status:"
/Applications/NoMachine.app/Contents/Frameworks/bin/nxserver --status 2>&1 | head -5

echo ""
echo "Port status:"
if lsof -i :4000 &>/dev/null; then
    echo "✅ Port 4000 is listening"
else
    echo "❌ Port 4000 is not listening"
fi

echo ""
echo "Configuration:"
for setting in "${REQUIRED_SETTINGS[@]}"; do
    if grep -q "^${setting}" "$CONFIG_FILE" 2>/dev/null; then
        echo "✅ $setting"
    else
        echo "❌ $setting (MISSING)"
    fi
done

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  Diagnostic Complete                                         ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "Next steps:"
echo "1. Verify Screen Recording permission (see Step 4 above)"
echo "2. If configuration is missing, run the manual command shown above"
echo "3. Test connection from remote client"
echo "4. Try both 'Console Session' and 'New Session' options"

