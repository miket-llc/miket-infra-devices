# Remote Desktop (RDP) Server Role for Windows

## Overview

This role configures Windows hosts to accept Remote Desktop Protocol (RDP) connections from Tailscale network only, implementing a defense-in-depth security model.

## Security Architecture: Defense in Depth

### Two-Layer Security Model

**Layer 1: Tailscale ACL (miket-infra responsibility)**
- Managed in `miket-infra/infra/tailscale/entra-prod/main.tf`
- Controls routing and access at the network layer
- Example: "Allow mike@miket.io to access RDP on all workstations"

**Layer 2: Device Firewall (miket-infra-devices responsibility - THIS ROLE)**
- Managed by this Ansible role
- Restricts RDP to Tailscale subnet (100.64.0.0/10) only
- Blocks all non-Tailscale RDP attempts at the host level

### Why Both Layers?

- **Network layer breach**: If Tailscale ACL is misconfigured, device firewall still blocks unauthorized IPs
- **ACL policy bug**: During updates, device firewalls maintain security posture
- **Compromised admin account**: Attacker can't bypass device-level restrictions
- **Defense in depth**: Zero-trust principle - never trust, always verify at every layer

## What This Role Does

1. **Enables RDP via Group Policy + Registry**
   - Group Policy prevents UI toggle from reverting
   - Registry provides fallback
   - Idempotent configuration

2. **Enables Network Level Authentication (NLA)**
   - Requires authentication before establishing session
   - More secure than legacy RDP

3. **Configures Windows Firewall**
   - Creates `RemoteDesktop-Tailscale` rule
   - Restricts RDP to Tailscale subnet only (100.64.0.0/10)
   - Idempotent - detects existing configuration

4. **Grants Administrator RDP Access**
   - Ensures all Administrators can RDP
   - Handles both local and Microsoft accounts

5. **Validates Configuration**
   - Verifies registry settings
   - Confirms RDP service is listening
   - Reports status and connection information

## Usage

### Apply to All Windows Workstations

```bash
cd ansible
ansible-playbook -i inventory/hosts.yml playbooks/configure-windows-rdp.yml
```

### Apply to Specific Host

```bash
ansible-playbook -i inventory/hosts.yml playbooks/configure-windows-rdp.yml -l wintermute
```

### Using remote_server.yml Playbook

```bash
# Configure all remote desktop servers (Windows RDP, Linux VNC)
ansible-playbook -i inventory/hosts.yml playbooks/remote_server.yml

# Only Windows RDP
ansible-playbook -i inventory/hosts.yml playbooks/remote_server.yml -l windows_workstations
```

## Idempotency

This role is fully idempotent:
- First run: Creates firewall rule, configures registry → reports "changed"
- Subsequent runs: Detects existing configuration → reports "ok" (no changes)
- Only `gpupdate /force` triggers changed (expected behavior)

**Test idempotency:**
```bash
ansible-playbook -i inventory/hosts.yml playbooks/configure-windows-rdp.yml -l wintermute
ansible-playbook -i inventory/hosts.yml playbooks/configure-windows-rdp.yml -l wintermute
# Second run should show: changed=1 (only gpupdate), firewall rule = ok
```

## Connecting from Clients

### From macOS (count-zero)

1. Install [Microsoft Remote Desktop](https://apps.apple.com/us/app/microsoft-remote-desktop/id1295203466) from Mac App Store
2. Ensure MagicDNS is enabled: `sudo tailscale up --accept-dns`
3. Open Microsoft Remote Desktop
4. Add PC: `wintermute.pangolin-vega.ts.net` or `armitage.pangolin-vega.ts.net`
5. Username: `mdt`
6. Connect

### From Linux (motoko)

```bash
# Using xfreerdp (recommended)
xfreerdp /v:wintermute.pangolin-vega.ts.net /u:mdt /cert:ignore

# Using remmina
remmina -c rdp://wintermute.pangolin-vega.ts.net:3389
```

### From Windows

```powershell
# Using built-in Remote Desktop Connection
mstsc /v:wintermute.pangolin-vega.ts.net
```

## Firewall Rule Details

**Rule Name:** `RemoteDesktop-Tailscale`
**Display Name:** Remote Desktop - Tailscale Only
**Protocol:** TCP
**Port:** 3389
**Direction:** Inbound
**Remote Address:** 100.64.0.0/10 (Tailscale CGNAT subnet)
**Action:** Allow
**Enabled:** Yes

This rule ensures that even if someone bypasses Tailscale ACL, the Windows firewall will block any non-Tailscale IP from accessing RDP.

## Troubleshooting

### RDP Not Working from count-zero

**Check Tailscale Connectivity:**
```bash
# On count-zero
ping 100.89.63.123  # wintermute's Tailscale IP
tailscale status | grep wintermute
```

**Check MagicDNS:**
```bash
# On count-zero
ping wintermute.pangolin-vega.ts.net
# If fails, enable: sudo tailscale up --accept-dns
```

**Check Firewall Rule:**
```powershell
# On wintermute/armitage
Get-NetFirewallRule -Name 'RemoteDesktop-Tailscale' | Get-NetFirewallAddressFilter
# Should show RemoteAddress: 100.64.0.0/255.192.0.0 (or 100.64.0.0/10)
```

### Verify RDP is Enabled

```powershell
# On Windows machine
Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server' -Name fDenyTSConnections
# Should return: 0 (enabled)

Get-Service TermService
# Should be: Running
```

## Variables

Defined in `ansible/roles/remote_server_windows_rdp/defaults/main.yml`:

```yaml
remote_rdp_port: 3389
remote_rdp_enabled: true
remote_rdp_nla_enabled: true
```

Optional in host_vars:
```yaml
rdp_users:
  - username1
  - username2
```

## Dependencies

- Ansible 2.9+
- Windows host with WinRM configured
- Tailscale installed and connected on all devices

## Related Documentation

- [Tailnet Architecture](../../../docs/architecture/tailnet.md)
- [IaC/CaC Principles](../../../docs/architecture/iac-cac-principles.md)
- [Remote Desktop Playbook](../../playbooks/REMOTE_DESKTOP.md)

