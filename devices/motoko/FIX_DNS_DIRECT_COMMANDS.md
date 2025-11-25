# Direct Commands to Fix DNS on Motoko

## Step 1: Connect to Motoko

Since DNS isn't working, try one of these methods:

### Option A: Try Tailscale IP directly (if Tailscale is partially working)
```bash
# From count-zero, try to get motoko's Tailscale IP
tailscale status | grep motoko

# Then SSH via IP
ssh mdt@<MOTOKO_TAILSCALE_IP>
# Or if Tailscale SSH works:
tailscale ssh mdt@motoko
```

### Option B: Use local network IP (if on same network)
```bash
# Try common local IPs
ssh mdt@192.168.1.201
# Or check your local network
```

### Option C: Physical access
If you have physical/keyboard access to motoko, run these commands directly.

---

## Step 2: Fix DNS First (Run these on motoko)

Once you're on motoko, run these commands **in order**:

### 2.1: Check current DNS status
```bash
cat /etc/resolv.conf
resolvectl status 2>/dev/null || echo "systemd-resolved not running"
```

### 2.2: Set temporary DNS servers (so we can download things)
```bash
# For systemd-resolved (Pop!_OS uses this)
sudo resolvectl dns $(ip route | grep default | awk '{print $5}' | head -1) 1.1.1.1 1.0.0.1

# OR if that doesn't work, edit resolv.conf directly
echo "nameserver 1.1.1.1" | sudo tee /etc/resolv.conf
echo "nameserver 1.0.0.1" | sudo tee -a /etc/resolv.conf
```

### 2.3: Flush DNS cache
```bash
sudo systemd-resolve --flush-caches 2>/dev/null || sudo resolvectl flush-caches
```

### 2.4: Test DNS
```bash
ping -c 2 google.com
ping -c 2 1.1.1.1
```

If DNS works now, continue to Step 3.

---

## Step 3: Check Tailscale Status

```bash
# Check if Tailscale is installed
which tailscale
which tailscaled

# Check service status
systemctl status tailscaled

# Check if connected
tailscale status
```

---

## Step 4: Fix Tailscale (if needed)

### 4.1: Install Tailscale (if missing)
```bash
curl -fsSL https://tailscale.com/install.sh | sh
```

### 4.2: Start Tailscale service
```bash
sudo systemctl enable tailscaled
sudo systemctl start tailscaled
sudo systemctl status tailscaled
```

### 4.3: Reconfigure Tailscale with DNS acceptance
```bash
sudo tailscale up \
  --advertise-tags=tag:server,tag:linux,tag:ansible \
  --accept-dns \
  --accept-routes \
  --ssh \
  --advertise-routes=192.168.1.0/24 \
  --advertise-exit-node
```

**CRITICAL:** The `--accept-dns` flag is required!

### 4.4: Verify Tailscale DNS
```bash
tailscale status --json | jq '.Self.DNS'
tailscale status --json | jq '.MagicDNSSuffix'
```

---

## Step 5: Configure System DNS to Use Tailscale

### 5.1: For systemd-resolved (Pop!_OS default)
```bash
# Get your network interface name
INTERFACE=$(ip route | grep default | awk '{print $5}' | head -1)
echo "Interface: $INTERFACE"

# Configure DNS to use Tailscale DNS (100.100.100.100) and fallback to Cloudflare
sudo resolvectl dns $INTERFACE 100.100.100.100 1.1.1.1 1.0.0.1

# Make it persistent (if using NetworkManager)
sudo nmcli connection modify $(nmcli -t -f NAME connection show --active | head -1) ipv4.dns "100.100.100.100 1.1.1.1"
sudo nmcli connection up $(nmcli -t -f NAME connection show --active | head -1)
```

### 5.2: Alternative: Configure NetworkManager directly
```bash
# List connections
nmcli connection show

# Set DNS (replace CONNECTION_NAME with your active connection)
sudo nmcli connection modify CONNECTION_NAME ipv4.dns "100.100.100.100 1.1.1.1"
sudo nmcli connection up CONNECTION_NAME
```

---

## Step 6: Verify Everything Works

```bash
# Test regular DNS
ping -c 2 google.com

# Test Tailscale MagicDNS
ping -c 2 motoko.pangolin-vega.ts.net
ping -c 2 wintermute.pangolin-vega.ts.net

# Check Tailscale status
tailscale status

# Check DNS servers
resolvectl status
```

---

## Quick One-Liner (if you have sudo access on motoko)

If you can get to a terminal on motoko, run this:

```bash
sudo bash -c '
# Fix DNS first
echo "nameserver 1.1.1.1" > /etc/resolv.conf
echo "nameserver 1.0.0.1" >> /etc/resolv.conf
systemctl restart systemd-resolved 2>/dev/null || true

# Check Tailscale
if ! command -v tailscale &> /dev/null; then
  curl -fsSL https://tailscale.com/install.sh | sh
fi

# Start service
systemctl enable tailscaled
systemctl start tailscaled
sleep 2

# Reconfigure
tailscale up --advertise-tags=tag:server,tag:linux,tag:ansible --accept-dns --accept-routes --ssh --advertise-routes=192.168.1.0/24 --advertise-exit-node

# Configure system DNS
INTERFACE=$(ip route | grep default | awk "{print \$5}" | head -1)
resolvectl dns $INTERFACE 100.100.100.100 1.1.1.1 1.0.0.1 2>/dev/null || true

# Test
echo "Testing DNS..."
ping -c 1 google.com && echo "✓ Regular DNS works"
ping -c 1 motoko.pangolin-vega.ts.net && echo "✓ MagicDNS works" || echo "MagicDNS may need a moment"
'
```


