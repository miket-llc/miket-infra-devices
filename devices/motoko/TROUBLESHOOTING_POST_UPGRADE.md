# Troubleshooting Tailscale & DNS After Pop!_OS 24 Beta Upgrade

## Quick Fix

Run the automated fix script:

```bash
cd ~/miket-infra-devices/devices/motoko
sudo ./fix-tailscale-post-upgrade.sh
```

## Manual Troubleshooting Steps

### 1. Check if Tailscale is Installed

```bash
which tailscale
which tailscaled
```

If not found, install:
```bash
curl -fsSL https://tailscale.com/install.sh | sh
```

### 2. Check Tailscale Service Status

```bash
systemctl status tailscaled
```

If not running:
```bash
sudo systemctl enable tailscaled
sudo systemctl start tailscaled
```

### 3. Check DNS Configuration

```bash
# Check resolv.conf
cat /etc/resolv.conf

# Check systemd-resolved (if present)
resolvectl status

# Check NetworkManager DNS (if present)
nmcli dev show | grep -i dns
```

### 4. Reconfigure Tailscale

```bash
sudo tailscale up \
  --advertise-tags=tag:server,tag:linux,tag:ansible \
  --accept-dns \
  --accept-routes \
  --ssh \
  --advertise-routes=192.168.1.0/24 \
  --advertise-exit-node
```

**CRITICAL:** The `--accept-dns` flag is required for MagicDNS to work!

### 5. Verify Configuration

```bash
# Check Tailscale status
tailscale status

# Check DNS configuration
tailscale status --json | jq '.Self.DNS'

# Test DNS resolution
ping google.com
ping motoko.pangolin-vega.ts.net
```

## Common Issues

### Issue: Tailscale command not found

**Solution:** Reinstall Tailscale
```bash
curl -fsSL https://tailscale.com/install.sh | sh
```

### Issue: tailscaled service won't start

**Solution:** Check logs and restart
```bash
sudo journalctl -u tailscaled -n 50
sudo systemctl restart tailscaled
```

### Issue: DNS not working

**Solution:** Ensure `--accept-dns` flag is set
```bash
sudo tailscale up --accept-dns --reset
sudo tailscale up \
  --advertise-tags=tag:server,tag:linux,tag:ansible \
  --accept-dns \
  --accept-routes \
  --ssh \
  --advertise-routes=192.168.1.0/24 \
  --advertise-exit-node
```

### Issue: Can't resolve Tailscale hostnames (.pangolin-vega.ts.net)

**Solution:** This is MagicDNS. Ensure:
1. `--accept-dns` flag is set (see above)
2. MagicDNS is enabled in Tailscale admin console
3. Wait a few minutes for DNS to propagate

### Issue: Regular DNS not working (can't resolve google.com)

**Solution:** Check system DNS configuration
```bash
# For systemd-resolved
sudo resolvectl status

# For NetworkManager
nmcli dev show | grep DNS

# Manually set DNS if needed (temporary)
echo "nameserver 1.1.1.1" | sudo tee /etc/resolv.conf
```

## Verification Checklist

- [ ] Tailscale is installed (`which tailscale`)
- [ ] tailscaled service is running (`systemctl status tailscaled`)
- [ ] Tailscale is connected (`tailscale status`)
- [ ] DNS is configured (`tailscale status --json | jq '.Self.DNS'`)
- [ ] Can resolve regular domains (`ping google.com`)
- [ ] Can resolve Tailscale hostnames (`ping motoko.pangolin-vega.ts.net`)
- [ ] Tags are correct (`tailscale status --json | jq '.Self.Tags'`)

## Getting Help

If issues persist:

1. Check Tailscale logs:
   ```bash
   sudo journalctl -u tailscaled -n 100
   ```

2. Check system DNS logs:
   ```bash
   sudo journalctl -u systemd-resolved -n 100
   ```

3. Verify Tailscale admin console shows device as connected

4. Check network connectivity:
   ```bash
   ping 8.8.8.8  # Test internet connectivity
   tailscale ping motoko  # Test Tailscale connectivity
   ```

