#!/bin/bash
# Copyright (c) 2025 MikeT LLC. All rights reserved.


# Quick Fix for Cloudflare Challenge Issue
# Enables Tailscale exit node to bypass Verizon network issue

set -e

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║     Quick Fix: Cloudflare Challenge Issue                    ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "APPROVAL REQUIRED:"
echo "1. Tailscale admin should be open in your browser"
echo "2. Find 'motoko' in machines list"
echo "3. Click '...' menu → 'Edit route settings'"
echo "4. Check 'Use as exit node' → Save"
echo ""
read -p "Press Enter when you've approved motoko as exit node..."

echo ""
echo "Checking for exit node..."
if tailscale exit-node list 2>&1 | grep -q "motoko"; then
    echo "✓ motoko exit node detected"
else
    echo "⚠ Waiting for approval to propagate..."
    sleep 5
    if ! tailscale exit-node list 2>&1 | grep -q "motoko"; then
        echo "✗ Exit node not found. Please ensure you've saved the settings."
        echo "  Then run this script again."
        exit 1
    fi
fi

echo ""
echo "Enabling exit node..."
sudo tailscale up --exit-node=motoko --exit-node-allow-lan-access=true

echo ""
echo "Testing connectivity..."
sleep 2

echo -n "Testing challenges.cloudflare.com: "
if curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 https://challenges.cloudflare.com/cdn-cgi/trace | grep -q "200"; then
    echo "✓ WORKING"
else
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 https://challenges.cloudflare.com)
    echo "HTTP $HTTP_CODE (was 500 before)"
fi

echo ""
echo "Testing in browser..."
open "https://www.avid.com"
sleep 3
open "https://chatgpt.com"

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                    FIX APPLIED                                ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "All traffic now routes through motoko, bypassing Verizon."
echo "Both avid.com and ChatGPT should work now."
echo ""
echo "To disable later: sudo tailscale up --exit-node=''"




