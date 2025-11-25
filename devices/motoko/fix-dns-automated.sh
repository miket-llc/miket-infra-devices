#!/bin/bash
# Automated DNS Fix for Motoko - Run this script on motoko
# Handles resolv.conf symlink issue properly

set -e

echo "=== Automated DNS Fix for Motoko ==="
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "❌ Please run with sudo: sudo bash $0"
    exit 1
fi

# Step 1: Find network interface
echo "[1/6] Finding network interface..."
INTERFACE=$(ip route | grep default | awk '{print $5}' | head -1)
if [ -z "$INTERFACE" ]; then
    echo "❌ Could not find network interface"
    exit 1
fi
echo "✓ Found interface: $INTERFACE"

# Step 2: Fix DNS via systemd-resolved (handles symlink)
echo ""
echo "[2/6] Configuring DNS via systemd-resolved..."
if command -v resolvectl &> /dev/null && systemctl is-active --quiet systemd-resolved 2>/dev/null; then
    resolvectl dns $INTERFACE 1.1.1.1 1.0.0.1
    resolvectl flush-caches
    echo "✓ DNS configured via systemd-resolved"
elif command -v nmcli &> /dev/null && systemctl is-active --quiet NetworkManager 2>/dev/null; then
    CONNECTION=$(nmcli -t -f NAME connection show --active | head -1)
    nmcli connection modify "$CONNECTION" ipv4.dns "1.1.1.1 1.0.0.1"
    nmcli connection up "$CONNECTION"
    echo "✓ DNS configured via NetworkManager"
else
    echo "⚠ Neither systemd-resolved nor NetworkManager found"
    echo "Removing resolv.conf symlink and creating direct file..."
    rm -f /etc/resolv.conf
    echo "nameserver 1.1.1.1" > /etc/resolv.conf
    echo "nameserver 1.0.0.1" >> /etc/resolv.conf
fi

sleep 2

# Step 3: Test DNS
echo ""
echo "[3/6] Testing DNS..."
if ping -c 1 -W 2 google.com &>/dev/null; then
    echo "✓ DNS working - can download packages"
else
    echo "⚠ DNS test failed - may need network restart"
fi

# Step 4: Check/Install Tailscale
echo ""
echo "[4/6] Checking Tailscale..."
if ! command -v tailscale &> /dev/null; then
    echo "Installing Tailscale..."
    curl -fsSL https://tailscale.com/install.sh | sh
else
    echo "✓ Tailscale already installed"
fi

# Step 5: Start Tailscale service
echo ""
echo "[5/6] Starting Tailscale service..."
systemctl enable tailscaled 2>/dev/null || true
systemctl start tailscaled
sleep 3

if systemctl is-active --quiet tailscaled; then
    echo "✓ tailscaled service running"
else
    echo "⚠ tailscaled service not running - checking status..."
    systemctl status tailscaled --no-pager -l | head -10
fi

# Step 6: Reconfigure Tailscale
echo ""
echo "[6/6] Reconfiguring Tailscale..."
echo "This may require authentication - you'll see a URL if needed"
tailscale up \
  --advertise-tags=tag:server,tag:linux,tag:ansible \
  --accept-dns \
  --accept-routes \
  --ssh \
  --advertise-routes=192.168.1.0/24 \
  --advertise-exit-node

sleep 3

# Configure DNS to use Tailscale DNS
echo ""
echo "Configuring DNS to use Tailscale DNS..."
if command -v resolvectl &> /dev/null && systemctl is-active --quiet systemd-resolved 2>/dev/null; then
    resolvectl dns $INTERFACE 100.100.100.100 1.1.1.1 1.0.0.1
    resolvectl flush-caches
    echo "✓ Tailscale DNS configured via systemd-resolved"
elif command -v nmcli &> /dev/null && systemctl is-active --quiet NetworkManager 2>/dev/null; then
    CONNECTION=$(nmcli -t -f NAME connection show --active | head -1)
    nmcli connection modify "$CONNECTION" ipv4.dns "100.100.100.100 1.1.1.1"
    nmcli connection up "$CONNECTION"
    echo "✓ Tailscale DNS configured via NetworkManager"
fi

# Final verification
echo ""
echo "=== Verification ==="
echo "Testing regular DNS:"
ping -c 1 -W 2 google.com &>/dev/null && echo "✓ Regular DNS works" || echo "✗ Regular DNS failed"

echo "Testing MagicDNS:"
ping -c 1 -W 2 motoko.pangolin-vega.ts.net &>/dev/null && echo "✓ MagicDNS works" || echo "⚠ MagicDNS may need a moment"

echo ""
echo "Tailscale status:"
tailscale status | head -10

echo ""
echo "DNS configuration:"
resolvectl status 2>/dev/null | head -20 || nmcli dev show | grep DNS || cat /etc/resolv.conf

echo ""
echo "=== Done ==="

