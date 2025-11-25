#!/bin/bash
# Copyright (c) 2025 MikeT LLC. All rights reserved.

# Deploy RDP configuration to Windows devices
# This script deploys the RDP configuration with Group Policy settings

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ANSIBLE_DIR="$REPO_ROOT/ansible"

cd "$REPO_ROOT"

echo "Deploying RDP configuration to Windows devices..."
echo ""

# Check if vault password file exists
if [ ! -f /etc/ansible/.vault-pass.txt ]; then
    echo "Error: Vault password file not found at /etc/ansible/.vault-pass.txt"
    echo "Please ensure the vault password file exists and is readable."
    exit 1
fi

# Deploy to all Windows devices or specific device
if [ -n "$1" ]; then
    LIMIT="--limit $1"
    echo "Deploying to: $1"
else
    LIMIT=""
    echo "Deploying to all Windows devices"
fi

echo ""
echo "Running Ansible playbook..."
cd "$ANSIBLE_DIR"

ansible-playbook \
    -i inventory/hosts.yml \
    playbooks/configure-windows-rdp.yml \
    $LIMIT \
    -v

echo ""
echo "✅ RDP deployment complete!"
echo ""
echo "To verify RDP is working:"
echo "  1. Check Windows Settings > System > Remote Desktop (should be ON)"
echo "  2. Try connecting via: <hostname>.pangolin-vega.ts.net:3389"
echo ""
echo "If the toggle still reverts, run the PowerShell script directly on the device:"
echo "  .\\scripts\\Configure-RDP-GroupPolicy.ps1"

