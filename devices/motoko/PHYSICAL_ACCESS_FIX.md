# Fix DNS on Motoko - Physical Access Required

Since remote access isn't working, you'll need physical/keyboard access to motoko.

## Option 1: Try VNC via IP Address First

From count-zero, try connecting via Tailscale IP:

```bash
# macOS Screen Sharing via IP
open vnc://100.92.23.71:5900
# Password: motoko123
```

Or if you have a VNC client:
```bash
vncviewer 100.92.23.71:5900
# Password: motoko123
```

---

## Option 2: Physical Access - Quick Fix

If you have keyboard/monitor access to motoko, follow these steps:

### Step 1: Open Terminal
Press `Ctrl+Alt+T` or open Terminal from applications.

### Step 2: Fix DNS Immediately
Copy and paste this entire block:

```bash
sudo bash << 'EOF'
# Fix DNS first
echo "nameserver 1.1.1.1" > /etc/resolv.conf
echo "nameserver 1.0.0.1" >> /etc/resolv.conf
systemctl restart systemd-resolved 2>/dev/null || true

# Test DNS
ping -c 2 google.com
EOF
```

### Step 3: Check Tailscale
```bash
# Check if Tailscale is installed
which tailscale

# Check service status
sudo systemctl status tailscaled
```

### Step 4: Install/Reinstall Tailscale (if needed)
```bash
curl -fsSL https://tailscale.com/install.sh | sh
```

### Step 5: Start Tailscale Service
```bash
sudo systemctl enable tailscaled
sudo systemctl start tailscaled
sudo systemctl status tailscaled
```

### Step 6: Reconfigure Tailscale
```bash
sudo tailscale up \
  --advertise-tags=tag:server,tag:linux,tag:ansible \
  --accept-dns \
  --accept-routes \
  --ssh \
  --advertise-routes=192.168.1.0/24 \
  --advertise-exit-node
```

**Note:** You may need to authenticate - it will show you a URL to visit.

### Step 7: Configure System DNS
```bash
# Get network interface
INTERFACE=$(ip route | grep default | awk '{print $5}' | head -1)
echo "Interface: $INTERFACE"

# Configure DNS via systemd-resolved
sudo resolvectl dns $INTERFACE 100.100.100.100 1.1.1.1 1.0.0.1

# Or via NetworkManager (if that doesn't work)
if command -v nmcli &> /dev/null; then
    CONNECTION=$(nmcli -t -f NAME connection show --active | head -1)
    sudo nmcli connection modify "$CONNECTION" ipv4.dns "100.100.100.100 1.1.1.1"
    sudo nmcli connection up "$CONNECTION"
fi
```

### Step 8: Verify
```bash
# Test regular DNS
ping -c 2 google.com

# Test MagicDNS (may take a moment)
ping -c 2 motoko.pangolin-vega.ts.net

# Check Tailscale status
tailscale status
```

---

## Option 3: All-in-One Script (Physical Access)

If you're physically at motoko, save this as a script and run it:

```bash
# Create the script
cat > /tmp/fix-dns.sh << 'SCRIPT'
#!/bin/bash
set -e

echo "=== Fixing DNS and Tailscale ==="

# Fix DNS first
echo "Step 1: Fixing DNS..."
echo "nameserver 1.1.1.1" | sudo tee /etc/resolv.conf
echo "nameserver 1.0.0.1" | sudo tee -a /etc/resolv.conf
sudo systemctl restart systemd-resolved 2>/dev/null || true
sleep 1

# Test DNS
if ping -c 1 -W 2 google.com &>/dev/null; then
    echo "✓ DNS working"
else
    echo "⚠ DNS may need network restart"
fi

# Install Tailscale if needed
if ! command -v tailscale &> /dev/null; then
    echo "Step 2: Installing Tailscale..."
    curl -fsSL https://tailscale.com/install.sh | sh
else
    echo "Step 2: Tailscale already installed"
fi

# Start service
echo "Step 3: Starting Tailscale service..."
sudo systemctl enable tailscaled
sudo systemctl start tailscaled
sleep 2

# Reconfigure
echo "Step 4: Reconfiguring Tailscale..."
sudo tailscale up \
  --advertise-tags=tag:server,tag:linux,tag:ansible \
  --accept-dns \
  --accept-routes \
  --ssh \
  --advertise-routes=192.168.1.0/24 \
  --advertise-exit-node

# Configure system DNS
echo "Step 5: Configuring system DNS..."
INTERFACE=$(ip route | grep default | awk '{print $5}' | head -1)
sudo resolvectl dns $INTERFACE 100.100.100.100 1.1.1.1 1.0.0.1 2>/dev/null || true

if command -v nmcli &> /dev/null && systemctl is-active --quiet NetworkManager 2>/dev/null; then
    CONNECTION=$(nmcli -t -f NAME connection show --active | head -1)
    sudo nmcli connection modify "$CONNECTION" ipv4.dns "100.100.100.100 1.1.1.1" 2>/dev/null || true
    sudo nmcli connection up "$CONNECTION" 2>/dev/null || true
fi

# Verify
echo ""
echo "Step 6: Verifying..."
ping -c 1 google.com &>/dev/null && echo "✓ Regular DNS works" || echo "✗ Regular DNS failed"
ping -c 1 motoko.pangolin-vega.ts.net &>/dev/null && echo "✓ MagicDNS works" || echo "⚠ MagicDNS may need a moment"

echo ""
echo "Tailscale status:"
tailscale status | head -10

echo ""
echo "=== Done ==="
SCRIPT

# Make executable and run
chmod +x /tmp/fix-dns.sh
sudo /tmp/fix-dns.sh
```

---

## Troubleshooting

### If DNS still doesn't work after fixing:

1. **Restart NetworkManager:**
   ```bash
   sudo systemctl restart NetworkManager
   ```

2. **Restart systemd-resolved:**
   ```bash
   sudo systemctl restart systemd-resolved
   ```

3. **Check network interface:**
   ```bash
   ip addr show
   ip route show
   ```

4. **Manually set DNS in NetworkManager GUI:**
   - Open Settings → Network
   - Click on your connection
   - Go to IPv4 settings
   - Set DNS to: `100.100.100.100, 1.1.1.1`

### If Tailscale won't start:

```bash
# Check logs
sudo journalctl -u tailscaled -n 50

# Check if service is enabled
systemctl is-enabled tailscaled

# Try manual start
sudo tailscaled
```

### If you can't authenticate Tailscale:

The `tailscale up` command will show you a URL. You'll need to:
1. Copy the URL
2. Open it on another device (like count-zero) that has internet
3. Authenticate there
4. Come back to motoko and it should be connected


