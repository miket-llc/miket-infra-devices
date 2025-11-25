#!/bin/bash
# Copyright (c) 2025 MikeT LLC. All rights reserved.

# Quick MagicDNS fix for Count-Zero
echo "Fixing MagicDNS on Count-Zero..."
tailscale up --advertise-tags=tag:workstation,tag:macos --accept-dns --ssh
sleep 3
echo "Verifying..."
DNS=$(tailscale status --json | jq -r '.Self.DNS // "NOT CONFIGURED"')
echo "DNS: $DNS"
echo "Testing hostname resolution..."
ping -c 1 motoko >/dev/null 2>&1 && echo "✅ motoko resolves" || echo "❌ motoko does not resolve"


