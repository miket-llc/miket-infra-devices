# Tailscale Integration Guide

## Repository Architecture

This repository (`miket-infra-devices`) works in conjunction with `miket-infra`:

- **miket-infra**: Defines Tailscale ACL policies, tags, and network rules via Terraform
- **miket-infra-devices**: Applies those tags to actual devices and manages their configurations

## Integration Points

### 1. Tag Definitions

Tags are **defined** in `../miket-infra/infra/tailscale/entra-prod/devices.tf`:

```terraform
tagOwners = {
  "tag:server"      = ["group:owners"]
  "tag:workstation" = ["group:owners"] 
  "tag:windows"     = ["group:owners"]
  "tag:linux"       = ["group:owners"]
  "tag:ansible"     = ["group:owners"]
  "tag:gaming"      = ["group:owners"]
}
```

Tags are **applied** to devices using scripts in this repo:

| Device | Tags | Script |
|--------|------|--------|
| motoko | `tag:server,tag:linux,tag:ansible` | `scripts/setup-tailscale.sh` |
| armitage | `tag:workstation,tag:windows,tag:gaming` | `scripts/Setup-Tailscale.ps1` |
| wintermute | `tag:workstation,tag:windows,tag:gaming` | `scripts/Setup-Tailscale.ps1` |
| count-zero | `tag:workstation,tag:macos` | `scripts/setup-tailscale.sh` |
| atom | `tag:server,tag:linux,tag:workstation` | `scripts/setup-tailscale.sh` |

### 2. ACL Rules

Network access is **controlled** in `../miket-infra/infra/tailscale/entra-prod/devices.tf`:

```hcl
# Ansible (motoko) can manage all devices
{
  action = "accept"
  src    = ["tag:ansible"]
  dst    = ["*:22,5985,5986"]  # SSH + WinRM
}

# Workstations can access servers
{
  action = "accept"  
  src    = ["tag:workstation"]
  dst    = ["tag:server:22,80,443,3000,5000,8080"]
}
```

### 3. SSH Rules

SSH access is **defined** for Tailscale SSH:

```hcl
# Ansible node can SSH to Linux/Mac devices
{
  action = "accept"
  src    = ["tag:ansible"]
  dst    = ["tag:linux", "tag:macos"]
  users  = ["root", "mdt", "ansible"]
}
```

## Setup Workflow

### Step 1: Deploy Tailscale ACLs (in miket-infra)

```bash
cd ../miket-infra/infra/tailscale/entra-prod
terraform plan
terraform apply
```

### Step 2: Configure Devices (in miket-infra-devices)

**On Linux/Mac devices:**
```bash
./scripts/setup-tailscale.sh [device-name]
```

**On Windows devices:**
```powershell
.\scripts\Setup-Tailscale.ps1 -DeviceName ARMITAGE
```

### Step 3: Setup Ansible Control Node (motoko)

See [Motoko Ansible Control Node Setup](./runbooks/motoko-ansible-setup.md) for complete instructions.

Quick setup:
```bash
# SSH to motoko (via local network if Tailscale not yet configured)
ssh mdt@192.168.1.201 -p 2222

# Run setup script
cd ~/miket-infra-devices
./scripts/setup-tailscale.sh motoko
```

### Step 4: Test Connectivity

**From motoko:**
```bash
# Test SSH to Linux devices
ansible linux -i ansible/inventory/hosts.yml -m ping

# Test WinRM to Windows devices  
ansible windows -i ansible/inventory/hosts.yml -m win_ping

# Test specific device
ansible armitage -i ansible/inventory/hosts.yml -m win_ping
```

## Ansible Management

Once configured, you can manage all devices from motoko:

### Windows Workstation Management
```bash
# Switch Armitage to gaming mode
ansible-playbook -i ansible/inventory/hosts.yml \
  ansible/playbooks/windows-workstation.yml \
  --limit armitage \
  --extra-vars "workstation_mode=gaming"

# Install software on all Windows machines
ansible windows -i ansible/inventory/hosts.yml \
  -m win_chocolatey \
  -a "name=vscode,docker-desktop state=present"
```

### Cross-Platform Management
```bash
# Update all devices
ansible-playbook -i ansible/inventory/hosts.yml \
  ansible/playbooks/site.yml

# Run ad-hoc commands
ansible all -i ansible/inventory/hosts.yml \
  -m shell -a "tailscale status"
```

## Network Topology

```
┌─────────────────────────────────────────────────┐
│                 Tailscale Network                │
│                  (100.64.0.0/10)                 │
├─────────────────────────────────────────────────┤
│                                                  │
│  motoko (100.92.23.71)                          │
│  Tags: server, linux, ansible                   │
│  Role: Ansible Control Node                     │
│     │                                           │
│     ├──SSH──> Other Linux/Mac devices          │
│     └──WinRM──> Windows devices                │
│                                                  │
│  armitage (100.x.x.x)                          │
│  Tags: workstation, windows, gaming            │
│  Role: Gaming/Dev Workstation                  │
│                                                  │
│  wintermute (100.x.x.x)                        │
│  Tags: workstation, windows, gaming            │
│  Role: Gaming/Dev Workstation                  │
│                                                  │
│  count-zero (100.x.x.x)                        │
│  Tags: workstation, macos                      │
│  Role: MacBook Development                     │
│                                                  │
│  atom (100.120.122.13)                         │
│  Tags: server, linux, workstation              │
│  Role: Resilience Node (battery-backed)        │
│                                                  │
└─────────────────────────────────────────────────┘
```

## Troubleshooting

### Can't SSH to motoko from workstation
1. Check ACL rules in `miket-infra/infra/tailscale/entra-prod/devices.tf`
2. Ensure motoko has `tag:server` or `tag:ansible`
3. Verify with: `tailscale status` on both devices

### Ansible can't reach Windows devices
1. Ensure WinRM is enabled: `Enable-PSRemoting -Force`
2. Check firewall allows 5985 from Tailscale network
3. Verify tags: `tailscale status --json | ConvertFrom-Json | Select -Expand Self`

### Tags not applying
1. Tags must be owned by your user/group in ACL policy
2. Use `--advertise-tags` when bringing up Tailscale
3. May need admin approval if not preauthorized

## Security Notes

- All traffic goes over WireGuard-encrypted Tailscale tunnels
- No ports exposed to the internet
- ACLs restrict access based on device tags
- Ansible passwords should be vault-encrypted
- WinRM uses NTLM auth over encrypted tunnel

## References

- [Tailscale ACL Documentation](https://tailscale.com/kb/1018/acls/)
- [Ansible Windows Setup](https://docs.ansible.com/ansible/latest/user_guide/windows_setup.html)
- [Terraform Tailscale Provider](https://registry.terraform.io/providers/tailscale/tailscale/latest)