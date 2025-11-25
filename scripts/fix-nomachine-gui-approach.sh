#!/bin/bash
# Copyright (c) 2025 MikeT LLC. All rights reserved.
#
# Alternative approach: Use NoMachine GUI to configure settings
# This script opens NoMachine preferences and provides instructions

echo "=== NoMachine Configuration Fix (GUI Approach) ==="
echo ""
echo "Since macOS System Integrity Protection prevents direct file editing,"
echo "we'll use the NoMachine GUI to configure the settings."
echo ""
echo "Opening NoMachine preferences..."
echo ""

# Try to open NoMachine preferences
open -a NoMachine 2>/dev/null || {
    echo "Could not open NoMachine automatically."
    echo "Please open NoMachine manually and go to Preferences > Server."
}

echo ""
echo "=== Manual Configuration Steps ==="
echo ""
echo "1. Open NoMachine application"
echo "2. Go to: NoMachine > Preferences > Server"
echo "3. Enable the following settings:"
echo "   - Enable console session sharing"
echo "   - Enable session sharing"
echo "   - Enable NX display output"
echo "   - Enable new sessions"
echo ""
echo "4. Restart NoMachine server:"
echo "   sudo /Applications/NoMachine.app/Contents/Frameworks/bin/nxserver --restart"
echo ""
echo "=== Alternative: Use Ansible ==="
echo ""
echo "If you have Ansible configured, run:"
echo "  cd /Users/miket/dev/miket-infra-devices/ansible"
echo "  ansible-playbook -i inventory/hosts.yml playbooks/nomachine_deploy.yml --limit count-zero --ask-become-pass"
echo ""

