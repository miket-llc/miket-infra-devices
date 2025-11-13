# Motoko Tailscale Reconnection Guide

## Current Issue

Motoko has fallen out of the Tailscale tailnet and needs to be reconnected.

**Status**: Logged out
**Login URL**: https://login.tailscale.com/a/2db50dc325389

## Reconnection Steps

### Step 1: Authenticate

You have two options:

#### Option A: Manual Login (Interactive)
1. Visit the login URL: https://login.tailscale.com/a/2db50dc325389
2. Authenticate with your Microsoft Entra ID account
3. Approve the device if prompted

#### Option B: Use Enrollment Key (Automated)
1. Get enrollment key from Terraform:
   ```bash
   cd ~/miket-infra/infra/tailscale/entra-prod
   terraform init  # If not already initialized
   terraform output enrollment_key
   ```
2. Use the key to authenticate (no manual approval needed)

### Step 2: Reconnect with Proper Configuration

After authentication, reconnect motoko with the correct tags and settings:

```bash
sudo tailscale up \
  --advertise-tags=tag:server,tag:linux,tag:ansible \
  --ssh \
  --accept-dns=true \
  --accept-routes=true \
  --advertise-routes=192.168.1.0/24
```

**What this does:**
- `--advertise-tags`: Applies tags for ACL rules (server, linux, ansible)
- `--ssh`: Enables Tailscale SSH
- `--accept-dns=true`: Accepts DNS settings from Tailscale (enables MagicDNS)
- `--accept-routes=true`: Accepts subnet routes
- `--advertise-routes`: Advertises local network (192.168.1.0/24) to other devices

### Step 3: Verify Connection

```bash
# Check status
tailscale status

# Check tags
tailscale status --json | jq '.Self.Tags'

# Check MagicDNS
tailscale status --json | jq '.MagicDNSSuffix'

# Test DNS resolution
ping motoko.pangolin-vega.ts.net
```

### Step 4: Verify MagicDNS

After reconnecting, MagicDNS should work automatically if:
1. MagicDNS is enabled in Terraform (`tailscale_dns_preferences.magic`)
2. Device is accepting DNS (`--accept-dns=true`)
3. DNS server is reachable (`100.100.100.100`)

Test MagicDNS:
```bash
# Should resolve to Tailscale IP
dig +short motoko.pangolin-vega.ts.net @100.100.100.100

# Or using system resolver
getent hosts motoko.pangolin-vega.ts.net
```

## Quick Reconnection Script

A script is available at `/tmp/reconnect-motoko.sh` that automates the reconnection after authentication.

**Usage:**
1. Authenticate manually (visit login URL)
2. Run: `sudo /tmp/reconnect-motoko.sh`

## Troubleshooting

### MagicDNS Not Working After Reconnection

1. **Check MagicDNS is enabled in Terraform**:
   ```bash
   cd ~/miket-infra/infra/tailscale/entra-prod
   terraform plan -target=tailscale_dns_preferences.magic
   terraform apply -target=tailscale_dns_preferences.magic
   ```

2. **Verify DNS acceptance**:
   ```bash
   sudo tailscale set --accept-dns=true
   ```

3. **Check DNS server**:
   ```bash
   resolvectl status tailscale0
   # Should show: DNS Servers: 100.100.100.100
   ```

4. **Restart Tailscale**:
   ```bash
   sudo systemctl restart tailscaled
   ```

### Wrong Tailnet

If you see a different tailnet suffix:
- Verify you're connected to the correct tailnet (`pangolin-vega.ts.net`)
- Check which tailnet you're supposed to be on
- Re-authenticate with the correct account if needed

### Tags Not Applying

1. Verify tags are owned by your user/group in ACL policy
2. Check ACL deployment:
   ```bash
   cd ~/miket-infra/infra/tailscale/entra-prod
   terraform plan
   terraform apply
   ```
3. May need admin approval if not preauthorized

## Architecture Reference

**All Devices in Infrastructure:**
- **motoko** (Linux server) - `tag:server,tag:linux,tag:ansible`
- **armitage** (Windows workstation) - `tag:workstation,tag:windows,tag:gaming`
- **wintermute** (Windows workstation) - `tag:workstation,tag:windows,tag:gaming`
- **count-zero** (macOS workstation) - `tag:workstation,tag:macos`

**Tailnet**: `pangolin-vega.ts.net`

## Related Documentation

- [Tailscale Integration Guide](../tailscale-integration.md)
- [Motoko Ansible Setup](./motoko-ansible-setup.md)
- [Tailscale SSH Setup](./tailscale-ssh-setup.md)

