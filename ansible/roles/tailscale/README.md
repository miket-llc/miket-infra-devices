# Tailscale Role

**Configuration-only role** - Assumes Tailscale is already installed and connected to the tailnet.

## Prerequisites

Tailscale **must be installed and connected** before this role can run. Ansible connects to devices via Tailscale hostnames, so Tailscale is a hard prerequisite.

## What This Role Does

- ✅ Configures Tailscale tags (based on device name)
- ✅ Ensures `--accept-dns` is set (MagicDNS)
- ✅ Configures `--accept-routes` if needed
- ✅ Enables Tailscale SSH (Linux/macOS only)
- ✅ Configures macOS MagicDNS resolver (`/etc/resolver/`)
- ✅ Configures exit node (server node only)

## What This Role Does NOT Do

- ❌ Install Tailscale (use bootstrap scripts)
- ❌ Authenticate to Tailscale (user must do this manually)

## Usage

```yaml
- hosts: tailnet_all
  roles:
    - tailscale
```

## Device Tags

Tags are automatically set based on `inventory_hostname`:
- `akira`: `tag:server,tag:linux,tag:ansible`
- `wintermute`: `tag:workstation,tag:windows,tag:gaming`
- `armitage`: `tag:workstation,tag:windows,tag:gaming`
- `count-zero`: `tag:workstation,tag:macos`

## Bootstrap Scripts

For initial Tailscale installation, use:
- Linux: `curl -fsSL https://tailscale.com/install.sh | sh`
- macOS: `scripts/bootstrap-macos.sh`
- Windows: `scripts/bootstrap-armitage.ps1` or `scripts/bootstrap-wintermute.ps1`



