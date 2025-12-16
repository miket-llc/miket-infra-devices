# macOS Tailscale Setup

## Overview

macOS devices use the **Standalone version** of Tailscale from `pkgs.tailscale.com`. This provides:
- Automatic DNS/MagicDNS configuration (Network Extension)
- Full `tailscale ssh` support (not sandboxed like App Store)
- No `/etc/resolver` hacks needed (unlike Homebrew)

## Prerequisites

1. macOS device with admin account
2. Admin password for `sudo` operations

## Quick Start

```bash
# Run bootstrap script (handles everything)
./scripts/bootstrap-macos.sh

# Or manually:
# 1. Download from https://pkgs.tailscale.com/stable/
# 2. Install the .pkg file
# 3. Open Tailscale, allow System Extension in Privacy & Security
# 4. Sign in with Microsoft (mike@miket.io)
```

## What the Bootstrap Script Does

1. **Installs Tailscale Standalone** - Downloads from pkgs.tailscale.com and installs
2. **Installs CLI wrapper** - Creates `/usr/local/bin/tailscale` wrapper script
3. **Enables Remote Login (SSH)** - via `systemsetup -setremotelogin on`
4. **Configures firewall** - Restricts SSH to Tailscale IPs only (100.64.0.0/10) via pf
5. **Sets up SSH directory** - Creates `~/.ssh/authorized_keys` with correct permissions

## Why Standalone?

| Feature | Standalone | App Store | Homebrew |
|---------|------------|-----------|----------|
| DNS/MagicDNS | ✅ Automatic | ✅ Automatic | ❌ Requires /etc/resolver hacks |
| System integration | ✅ Network Extension | ✅ Network Extension | ❌ Userspace networking |
| `tailscale ssh` | ✅ Works | ❌ Sandboxed | ✅ Works |
| Updates | Manual/script | App Store | `brew upgrade` |

**Standalone is the only version with both working DNS AND `tailscale ssh`.**

## SSH Access

### Outbound (from macOS to other devices)
```bash
# Tailscale SSH (identity-based, no keys needed)
tailscale ssh mdt@akira
tailscale ssh mdt@motoko

# Or traditional SSH (requires keys in authorized_keys)
ssh mdt@akira.pangolin-vega.ts.net
ssh mdt@motoko.pangolin-vega.ts.net
```

### Inbound (from other devices to macOS)
SSH is restricted to Tailscale IPs only via pf firewall rules. External IPs cannot SSH in.

```bash
# From akira or motoko:
ssh mdt@count-zero.pangolin-vega.ts.net
```

Requires SSH key in `~/.ssh/authorized_keys` on the macOS device.

## Firewall Configuration

The bootstrap script creates `/etc/pf.anchors/tailscale-ssh`:

```
# Allow SSH from Tailscale IPs
pass in quick on utun* proto tcp from 100.64.0.0/10 to any port 22
pass in quick proto tcp from 100.64.0.0/10 to any port 22

# Block SSH from everywhere else
block drop in quick proto tcp from any to any port 22
```

This ensures SSH only works from within the tailnet.

### Verify Firewall Rules
```bash
sudo pfctl -a tailscale-ssh -sr
```

## Troubleshooting

### DNS Not Resolving
The App Store version should handle this automatically. If not working:
```bash
# Check Tailscale is connected
tailscale status

# Test DNS
ping akira.pangolin-vega.ts.net
```

### SSH Not Working (Inbound)
1. Check Remote Login is enabled: `sudo systemsetup -getremotelogin`
2. Check firewall rules: `sudo pfctl -a tailscale-ssh -sr`
3. Check authorized_keys has the remote device's public key
4. Verify connecting from a Tailscale IP (100.x.x.x)

### CLI Not Found
```bash
# Reinstall wrapper
sudo mkdir -p /usr/local/bin
sudo tee /usr/local/bin/tailscale << 'EOF'
#!/bin/sh
exec /Applications/Tailscale.app/Contents/MacOS/Tailscale "$@"
EOF
sudo chmod +x /usr/local/bin/tailscale
```

## SSH Key Exchange

To enable passwordless SSH between devices:

```bash
# On macOS, get public key
cat ~/.ssh/id_ed25519.pub

# On remote device (e.g., akira), add to authorized_keys
echo "ssh-ed25519 AAAA... count-zero" >> ~/.ssh/authorized_keys

# Repeat in reverse for inbound access
```

## Ansible Integration

After bootstrap, the device can be managed via Ansible from the control node (motoko):

```bash
# Test connectivity
ansible count-zero -m ping -i inventory/hosts.yml

# Run playbooks
ansible-playbook -i inventory/hosts.yml playbooks/deploy-baseline-tools.yml --limit count-zero
```

## Related Documentation

- [Bootstrap Script](../../scripts/bootstrap-macos.sh)
- [Tailscale SSH Setup](./tailscale-ssh-setup.md)
- [Tailnet Reference](../reference/tailscale-integration.md)
