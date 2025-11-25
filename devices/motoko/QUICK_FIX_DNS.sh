#!/bin/bash
# Quick DNS Fix for Motoko - Copy and paste this entire script into motoko's terminal
# Run with: sudo bash (then paste the script)

set -e

echo "=== Fixing DNS on Motoko ==="

# Step 1: Set temporary DNS so we can download things
echo "Step 1: Setting temporary DNS..."
# Check if resolv.conf is a symlink (managed by systemd-resolved on Pop!_OS)
if [ -L /etc/resolv.conf ]; then
    echo "resolv.conf is a symlink - configuring via systemd-resolved..."
    INTERFACE=$(ip route | grep default | awk '{print $5}' | head -1)
    resolvectl dns $INTERFACE 1.1.1.1 1.0.0.1
    resolvectl flush-caches
elif command -v nmcli &> /dev/null && systemctl is-active --quiet NetworkManager 2>/dev/null; then
    echo "Configuring DNS via NetworkManager..."
    CONNECTION=$(nmcli -t -f NAME connection show --active | head -1)
    nmcli connection modify "$CONNECTION" ipv4.dns "1.1.1.1 1.0.0.1"
    nmcli connection up "$CONNECTION"
else
    echo "Falling back to direct resolv.conf edit (removing symlink first)..."
    sudo rm -f /etc/resolv.conf
    echo "nameserver 1.1.1.1" > /etc/resolv.conf
    echo "nameserver 1.0.0.1" >> /etc/resolv.conf
fi
sleep 2

# Test DNS
if ping -c 1 -W 2 google.com &>/dev/null; then
    echo "✓ DNS working - can download packages"
else
    echo "⚠ DNS still not working - may need network restart"
fi

# Step 2: Check/Install Tailscale
echo ""
echo "Step 2: Checking Tailscale..."
if ! command -v tailscale &> /dev/null; then
    echo "Installing Tailscale..."
    curl -fsSL https://tailscale.com/install.sh | sh
else
    echo "✓ Tailscale already installed"
fi

# Step 3: Start Tailscale service
echo ""
echo "Step 3: Starting Tailscale service..."
systemctl enable tailscaled 2>/dev/null || true
systemctl start tailscaled
sleep 2

if systemctl is-active --quiet tailscaled; then
    echo "✓ tailscaled service running"
else
    echo "⚠ tailscaled service not running - checking status..."
    systemctl status tailscaled --no-pager -l | head -20
fi

# Step 4: Reconfigure Tailscale with DNS acceptance
echo ""
echo "Step 4: Reconfiguring Tailscale..."
tailscale up \
  --advertise-tags=tag:server,tag:linux,tag:ansible \
  --accept-dns \
  --accept-routes \
  --ssh \
  --advertise-routes=192.168.1.0/24 \
  --advertise-exit-node

sleep 3

# Step 5: Configure system DNS to use Tailscale DNS
echo ""
echo "Step 5: Configuring system DNS..."
INTERFACE=$(ip route | grep default | awk '{print $5}' | head -1)
echo "Using interface: $INTERFACE"

# Configure DNS via systemd-resolved (preferred method for Pop!_OS)
if command -v resolvectl &> /dev/null && systemctl is-active --quiet systemd-resolved 2>/dev/null; then
    echo "Configuring via systemd-resolved..."
    resolvectl dns $INTERFACE 100.100.100.100 1.1.1.1 1.0.0.1
    resolvectl flush-caches
    echo "✓ DNS configured via systemd-resolved"
# Fallback to NetworkManager
elif command -v nmcli &> /dev/null && systemctl is-active --quiet NetworkManager 2>/dev/null; then
    echo "Configuring via NetworkManager..."
    CONNECTION=$(nmcli -t -f NAME connection show --active | head -1)
    if [ -n "$CONNECTION" ]; then
        nmcli connection modify "$CONNECTION" ipv4.dns "100.100.100.100 1.1.1.1"
        nmcli connection up "$CONNECTION"
        echo "✓ DNS configured via NetworkManager"
    fi
else
    echo "⚠ Could not configure DNS automatically - manual configuration required"
fi

# Step 6: Verify
echo ""
echo "Step 6: Verifying..."
echo "Testing regular DNS:"
ping -c 1 -W 2 google.com &>/dev/null && echo "✓ Regular DNS works" || echo "✗ Regular DNS failed"

echo "Testing MagicDNS:"
ping -c 1 -W 2 motoko.pangolin-vega.ts.net &>/dev/null && echo "✓ MagicDNS works" || echo "⚠ MagicDNS may need a moment"

echo ""
echo "Tailscale status:"
tailscale status | head -10

echo ""
echo "DNS configuration:"
cat /etc/resolv.conf

echo ""
echo "=== Done ==="
echo "If DNS still doesn't work, try:"
echo "  sudo systemctl restart NetworkManager"
echo "  sudo systemctl restart systemd-resolved"

