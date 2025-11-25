#!/bin/bash
# Copyright (c) 2025 MikeT LLC. All rights reserved.
#
# Comprehensive NoMachine fix for count-zero (macOS)
# Handles stuck sessions, configuration, and permissions

set -euo pipefail

echo "=== Comprehensive NoMachine Fix for count-zero ==="
echo ""

# Step 1: Kill any stuck NoMachine processes
echo "Step 1: Cleaning up stuck processes..."
pkill -9 nxserver 2>/dev/null || true
pkill -9 nxnode 2>/dev/null || true
pkill -9 nxd 2>/dev/null || true
sleep 2

# Step 2: Check and fix configuration using Ansible if available
echo ""
echo "Step 2: Attempting configuration fix..."
if command -v ansible-playbook &> /dev/null; then
    echo "Ansible found - attempting to apply configuration..."
    cd /Users/miket/dev/miket-infra-devices/ansible 2>/dev/null && \
    ansible-playbook -i inventory/hosts.yml playbooks/nomachine_deploy.yml \
        --limit count-zero --ask-become-pass --tags nomachine:server 2>&1 | tail -30 || \
    echo "Ansible configuration failed or requires password"
else
    echo "Ansible not available - manual configuration required"
    echo ""
    echo "MANUAL CONFIGURATION REQUIRED:"
    echo "Due to macOS System Integrity Protection, the config file cannot be edited programmatically."
    echo ""
    echo "Please run this command manually (will prompt for password):"
    echo "  sudo sh -c 'echo \"\" >> /Applications/NoMachine.app/Contents/Frameworks/etc/server.cfg && echo \"# NoMachine UI rendering settings\" >> /Applications/NoMachine.app/Contents/Frameworks/etc/server.cfg && echo \"EnableConsoleSessionSharing=1\" >> /Applications/NoMachine.app/Contents/Frameworks/etc/server.cfg && echo \"EnableSessionSharing=1\" >> /Applications/NoMachine.app/Contents/Frameworks/etc/server.cfg && echo \"EnableNXDisplayOutput=1\" >> /Applications/NoMachine.app/Contents/Frameworks/etc/server.cfg && echo \"EnableNewSession=1\" >> /Applications/NoMachine.app/Contents/Frameworks/etc/server.cfg'"
    echo ""
    echo "Then restart NoMachine:"
    echo "  sudo /Applications/NoMachine.app/Contents/Frameworks/bin/nxserver --restart"
fi

# Step 3: Restart NoMachine server
echo ""
echo "Step 3: Restarting NoMachine server..."
osascript <<'EOF' 2>/dev/null || true
do shell script "/Applications/NoMachine.app/Contents/Frameworks/bin/nxserver --restart" with administrator privileges
EOF

sleep 3

# Step 4: Verify server status
echo ""
echo "Step 4: Verifying server status..."
/Applications/NoMachine.app/Contents/Frameworks/bin/nxserver --status 2>&1 | head -20

# Step 5: Check screen recording permissions
echo ""
echo "Step 5: Screen Recording Permission Check"
echo "Please verify in System Preferences > Security & Privacy > Privacy > Screen Recording"
echo "that NoMachine has Screen Recording permission enabled."
echo ""
echo "To grant permission:"
echo "1. Open System Preferences"
echo "2. Go to Security & Privacy > Privacy"
echo "3. Select Screen Recording from the left sidebar"
echo "4. Ensure NoMachine is listed and checked"
echo "5. If not listed, click + and add: /Applications/NoMachine.app"
echo ""

# Step 6: Test connectivity
echo "Step 6: Testing connectivity..."
if lsof -i :4000 &>/dev/null; then
    echo "✅ Port 4000 is listening"
else
    echo "❌ Port 4000 is not listening"
fi

echo ""
echo "=== Fix Complete ==="
echo ""
echo "Next steps:"
echo "1. Verify Screen Recording permission (see Step 5 above)"
echo "2. If configuration wasn't applied automatically, run the manual command shown above"
echo "3. Test connection from remote client"
echo "4. Try both 'Console Session' and 'New Session' options"


