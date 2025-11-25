# Fix DNS on Pop!_OS (Handles resolv.conf Symlink)

## Important: resolv.conf is a Symlink!

On Pop!_OS 24, `/etc/resolv.conf` is a **symlink** managed by `systemd-resolved`. You **cannot** edit it directly - it will be overwritten.

## Correct Method: Use systemd-resolved

### Step 1: Find Your Network Interface

```bash
# Find your active network interface
ip route | grep default | awk '{print $5}' | head -1
# Common names: enp0s31f6, wlan0, eth0, etc.
```

### Step 2: Configure DNS via resolvectl

```bash
# Replace INTERFACE_NAME with your interface from Step 1
INTERFACE=$(ip route | grep default | awk '{print $5}' | head -1)
sudo resolvectl dns $INTERFACE 1.1.1.1 1.0.0.1

# Flush DNS cache
sudo resolvectl flush-caches
```

### Step 3: Verify DNS

```bash
# Check what DNS is configured
resolvectl status

# Test DNS resolution
ping -c 2 google.com
```

## Alternative: Use NetworkManager

If NetworkManager is managing your connection:

```bash
# List active connections
nmcli connection show --active

# Set DNS (replace CONNECTION_NAME with your connection)
sudo nmcli connection modify CONNECTION_NAME ipv4.dns "1.1.1.1 1.0.0.1"

# Apply changes
sudo nmcli connection up CONNECTION_NAME
```

## For Tailscale DNS (After Tailscale is Working)

Once Tailscale is connected, configure DNS to use Tailscale's DNS server:

```bash
# Via systemd-resolved (preferred)
INTERFACE=$(ip route | grep default | awk '{print $5}' | head -1)
sudo resolvectl dns $INTERFACE 100.100.100.100 1.1.1.1 1.0.0.1
sudo resolvectl flush-caches

# Or via NetworkManager
sudo nmcli connection modify CONNECTION_NAME ipv4.dns "100.100.100.100 1.1.1.1"
sudo nmcli connection up CONNECTION_NAME
```

## Why Direct Edit Doesn't Work

```bash
# This WON'T work - resolv.conf is a symlink
sudo echo "nameserver 1.1.1.1" > /etc/resolv.conf

# Check if it's a symlink
ls -la /etc/resolv.conf
# Output: /etc/resolv.conf -> ../run/systemd/resolve/stub-resolv.conf
```

The symlink points to `/run/systemd/resolve/stub-resolv.conf`, which is managed by `systemd-resolved`. Any direct edits will be overwritten.

## Complete Fix Script (Handles Symlink)

```bash
sudo bash << 'EOF'
# Find interface
INTERFACE=$(ip route | grep default | awk '{print $5}' | head -1)
echo "Using interface: $INTERFACE"

# Configure DNS via systemd-resolved
if command -v resolvectl &> /dev/null && systemctl is-active --quiet systemd-resolved; then
    echo "Configuring DNS via systemd-resolved..."
    resolvectl dns $INTERFACE 1.1.1.1 1.0.0.1
    resolvectl flush-caches
    echo "✓ DNS configured"
elif command -v nmcli &> /dev/null && systemctl is-active --quiet NetworkManager; then
    echo "Configuring DNS via NetworkManager..."
    CONNECTION=$(nmcli -t -f NAME connection show --active | head -1)
    nmcli connection modify "$CONNECTION" ipv4.dns "1.1.1.1 1.0.0.1"
    nmcli connection up "$CONNECTION"
    echo "✓ DNS configured"
else
    echo "⚠ Neither systemd-resolved nor NetworkManager found"
    echo "Manual DNS configuration required"
fi

# Test DNS
ping -c 1 google.com && echo "✓ DNS working" || echo "✗ DNS failed"
EOF
```

## Troubleshooting

### Check Current DNS Configuration

```bash
# See what DNS servers are configured
resolvectl status

# Or check NetworkManager
nmcli dev show | grep DNS
```

### Check resolv.conf Symlink Target

```bash
# See where the symlink points
readlink -f /etc/resolv.conf

# Check if the target exists
ls -la /run/systemd/resolve/stub-resolv.conf
```

### Restart Services if Needed

```bash
# Restart systemd-resolved
sudo systemctl restart systemd-resolved

# Or restart NetworkManager
sudo systemctl restart NetworkManager
```

