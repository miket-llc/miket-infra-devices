# Tailscale SSH Troubleshooting - Motoko

## Issue Fixed

**Problem:** Other nodes couldn't SSH to motoko via Tailscale SSH or MagicDNS.

**Root Cause:** SSH was configured to listen only on:
- `127.0.0.1` (localhost only)
- `100.111.12.30` (old IP, not the current Tailscale IP)

Motoko's actual Tailscale IP is `100.92.23.71`, but SSH wasn't listening on that interface.

## Solution Applied

1. **Updated SSH Configuration**
   - Changed `ListenAddress` from `127.0.0.1` and `100.111.12.30` to `0.0.0.0`
   - SSH now listens on all interfaces, including Tailscale interface
   - Reloaded SSH service

2. **Verified Tailscale SSH**
   - Confirmed Tailscale SSH is enabled: `sudo tailscale set --ssh=true`
   - Verified SSH capability is present in Tailscale status

3. **Verified MagicDNS**
   - MagicDNS suffix: `pangolin-vega.ts.net`
   - DNS name: `motoko.pangolin-vega.ts.net`
   - Resolves to: `100.92.23.71`

## Current Status

✅ SSH listening on all interfaces (`0.0.0.0:22`)
✅ Tailscale SSH enabled
✅ MagicDNS configured and working
✅ Firewall allows Tailscale IPs (`100.64.0.0/10`)

## Testing

From other nodes, test connectivity:

```bash
# Test Tailscale SSH (uses Tailscale's built-in SSH):
tailscale ssh mdt@motoko.pangolin-vega.ts.net

# Test regular SSH via MagicDNS:
ssh mdt@motoko.pangolin-vega.ts.net

# Test via Tailscale IP directly:
ssh mdt@100.92.23.71
```

All three methods should now work.

## Configuration Details

**SSH Config** (`/etc/ssh/sshd_config`):
```
Port 22
ListenAddress 0.0.0.0  # Listen on all interfaces
```

**Tailscale Status**:
- Hostname: `motoko`
- DNS Name: `motoko.pangolin-vega.ts.net`
- Tailscale IP: `100.92.23.71`
- SSH Enabled: `true`

**Firewall Rules**:
- `22/tcp ALLOW 100.64.0.0/10` (Tailscale IP range)
- `22/tcp ALLOW 127.0.0.1` (localhost)

## Related Documentation

- [Tailscale SSH Setup](../docs/runbooks/tailscale-ssh-setup.md)
- [Tailscale Integration](../docs/tailscale-integration.md)

