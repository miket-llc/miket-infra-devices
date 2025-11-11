# Motoko Ansible Control Node Setup

## Overview

Motoko is configured as the Ansible control node for managing all infrastructure devices over the Tailscale network. This document describes the setup and configuration.

## Prerequisites

1. **Tailscale Network**: Devices must be connected to the tailnet (`pangolin-vega.ts.net`)
2. **ACL Configuration**: Tailscale ACLs must be deployed from `miket-infra` repository
3. **Device Tags**: Motoko must have `tag:ansible` tag applied

## Setup Steps

### 1. Configure Tailscale on Motoko

From motoko, run:

```bash
cd ~/miket-infra-devices
./scripts/setup-tailscale.sh motoko
```

This will:
- Install Tailscale if not present
- Configure motoko with tags: `tag:server,tag:linux,tag:ansible`
- Enable Tailscale SSH
- Install Ansible and required dependencies

### 2. Verify Tailscale Connection

```bash
tailscale status
```

You should see motoko connected with the correct tags.

### 3. Verify SSH Access to Other Devices

From motoko, test SSH access to other devices:

```bash
# Test SSH to Linux/Mac devices (uses Tailscale SSH)
tailscale ssh mdt@count-zero.pangolin-vega.ts.net "hostname"

# Test WinRM to Windows devices (uses regular network ACL)
# Note: Windows devices use WinRM, not SSH
ansible windows -i ~/miket-infra-devices/ansible/inventory/hosts.yml -m win_ping
```

### 4. Test Ansible Connectivity

```bash
cd ~/miket-infra-devices

# Test Linux devices
ansible linux -i ansible/inventory/hosts.yml -m ping

# Test macOS devices
ansible macos -i ansible/inventory/hosts.yml -m ping

# Test Windows devices (requires WinRM)
ansible windows -i ansible/inventory/hosts.yml -m win_ping
```

## Tailscale SSH Configuration

Motoko uses Tailscale SSH to connect to Linux and macOS devices. The ACL rules in `miket-infra/infra/tailscale/entra-prod/main.tf` allow:

```hcl
# Ansible node can SSH to all Linux/Mac devices
{
  action = "accept"
  src    = ["tag:ansible"]
  dst    = ["tag:linux", "tag:macos"]
  users  = ["root", "mdt", "ansible", "autogroup:nonroot"]
}
```

This means motoko (with `tag:ansible`) can SSH to any device tagged `tag:linux` or `tag:macos` as users `mdt`, `root`, or `ansible`.

## Windows Device Access

Windows devices use WinRM (not SSH) for Ansible management. The network ACL allows:

```hcl
# Ansible control node can manage all devices
{
  action = "accept"
  src    = ["tag:ansible"]
  dst    = ["*:22,5985,5986"]  # SSH + WinRM
}
```

This allows motoko to connect to Windows devices on ports 5985 (WinRM HTTP) and 5986 (WinRM HTTPS).

## Running Ansible Playbooks

From motoko:

```bash
cd ~/miket-infra-devices

# Run a playbook on all devices
ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/standardize-users.yml

# Run a playbook on specific device
ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/windows-workstation.yml --limit armitage

# Run ad-hoc commands
ansible all -i ansible/inventory/hosts.yml -m shell -a "tailscale status"
```

## Troubleshooting

### Cannot SSH to Linux/Mac Devices

1. **Verify tags**: Ensure motoko has `tag:ansible` and target device has `tag:linux` or `tag:macos`
   ```bash
   tailscale status --json | jq '.Self.Tags'
   ```

2. **Verify ACL deployment**: Ensure ACLs are deployed from miket-infra
   ```bash
   cd ~/miket-infra/infra/tailscale/entra-prod
   terraform plan
   ```

3. **Test Tailscale SSH directly**:
   ```bash
   tailscale ssh mdt@count-zero.pangolin-vega.ts.net
   ```

### Cannot Connect to Windows Devices

1. **Verify WinRM is enabled** on Windows devices
2. **Check firewall rules** allow WinRM (ports 5985/5986)
3. **Verify network ACL** allows `tag:ansible` → `*:5985,5986`
4. **Test WinRM connectivity**:
   ```bash
   ansible windows -i ansible/inventory/hosts.yml -m win_ping
   ```

### Ansible Cannot Resolve Hostnames

Ensure MagicDNS is enabled in Tailscale. The inventory uses `.pangolin-vega.ts.net` hostnames which require MagicDNS.

## Inventory Configuration

The Ansible inventory (`ansible/inventory/hosts.yml`) uses Tailscale hostnames:

- Linux: `motoko.pangolin-vega.ts.net`
- macOS: `count-zero.pangolin-vega.ts.net`
- Windows: `armitage.pangolin-vega.ts.net`, `wintermute.pangolin-vega.ts.net`

All devices use the `mdt` user for Ansible connections.

## Security Notes

- **SSH Keys**: Tailscale SSH uses Entra ID authentication, no SSH keys needed
- **WinRM**: Windows devices require password authentication (stored in Ansible Vault)
- **Network Isolation**: All traffic flows over Tailscale's encrypted mesh network
- **ACL Enforcement**: Access is controlled by Tailscale ACLs defined in miket-infra

## Related Documentation

- [Tailscale Integration Guide](../tailscale-integration.md)
- [SSH User Mapping](./ssh-user-mapping.md)
- [Tailscale SSH Setup](./tailscale-ssh-setup.md)
- [Ansible Windows Setup](../ansible-windows-setup.md)

