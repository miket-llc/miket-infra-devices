# Armitage Windows Workstation Setup Runbook

This runbook guides you through setting up Armitage (Windows 11 Pro laptop) for Ansible management from the motoko control node.

## Prerequisites

- Armitage is running Windows 11 Pro
- Administrator access on armitage
- Tailscale account access (via miket-infra ACLs)
- motoko is already configured as Ansible control node

## Quick Setup

### One-Command Bootstrap

From armitage (as Administrator):

```powershell
# Clone repository if needed
git clone https://github.com/miket-llc/miket-infra-devices.git C:\Users\$env:USERNAME\dev\miket-infra-devices
cd C:\Users\$env:USERNAME\dev\miket-infra-devices

# Run bootstrap script
.\scripts\bootstrap-armitage.ps1
```

This script will:
1. Configure WinRM for Ansible management
2. Configure Tailscale with proper tags (`tag:workstation,tag:windows,tag:gaming`)
3. Verify connectivity

## Manual Setup Steps

If you prefer manual setup or need to troubleshoot:

### Step 1: Configure WinRM

WinRM (Windows Remote Management) is required for Ansible to manage Windows devices.

```powershell
# Run as Administrator
.\scripts\Setup-WinRM.ps1
```

Or manually:

```powershell
# Enable WinRM
Enable-PSRemoting -Force -SkipNetworkProfileCheck

# Configure for Ansible
Set-Item WSMan:\localhost\Service\Auth\Basic -Value $true
Set-Item WSMan:\localhost\Service\AllowUnencrypted -Value $true

# Start and enable service
Start-Service WinRM
Set-Service -Name WinRM -StartupType Automatic

# Configure firewall for Tailscale network
New-NetFirewallRule -DisplayName "WinRM-HTTP-Tailscale" `
    -Direction Inbound -Protocol TCP -LocalPort 5985 `
    -RemoteAddress 100.64.0.0/10 -Action Allow
```

### Step 2: Configure Tailscale

Tailscale provides secure network connectivity for Ansible management.

```powershell
# Run as Administrator
.\scripts\Setup-Tailscale.ps1 -DeviceName ARMITAGE
```

This will:
- Install Tailscale if not present
- Configure with tags: `tag:workstation,tag:windows,tag:gaming`
- Connect to the tailnet

**Required Tags:**
- `tag:workstation` - Identifies as workstation device
- `tag:windows` - Windows OS family
- `tag:gaming` - Gaming-capable device

### Step 3: Verify Setup

**On armitage:**

```powershell
# Check WinRM status
Get-Service WinRM

# Check Tailscale status
tailscale status

# Get Tailscale IP
tailscale status --json | ConvertFrom-Json | Select -Expand Self | Select TailscaleIPs
```

**From motoko:**

```bash
# Test WinRM connectivity
ansible armitage -i ~/miket-infra-devices/ansible/inventory/hosts.yml -m win_ping
```

Expected output:
```
armitage | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
```

## Running Ansible Playbooks

Once setup is complete, you can manage armitage from motoko:

### Test Connectivity

```bash
# From motoko
cd ~/miket-infra-devices
ansible armitage -i ansible/inventory/hosts.yml -m win_ping
```

### Run Windows Workstation Playbook

```bash
# Configure armitage with standard workstation settings
ansible-playbook -i ansible/inventory/hosts.yml \
  ansible/playbooks/windows-workstation.yml \
  --limit armitage
```

This playbook will:
- Ensure WinRM is configured
- Install Chocolatey package manager
- Install development tools (Git, VS Code, Docker Desktop, etc.)
- Enable WSL2 features
- Configure NVIDIA GPU settings
- Set up Windows Defender exclusions
- Ensure Tailscale is running

### Run Specific Tasks

```bash
# Install packages only
ansible-playbook -i ansible/inventory/hosts.yml \
  ansible/playbooks/windows-workstation.yml \
  --limit armitage \
  --tags packages

# Configure WSL only
ansible-playbook -i ansible/inventory/hosts.yml \
  ansible/playbooks/windows-workstation.yml \
  --limit armitage \
  --tags wsl
```

### Standardize User Accounts

```bash
# Create/standardize user accounts across infrastructure
ansible-playbook -i ansible/inventory/hosts.yml \
  ansible/playbooks/standardize-users.yml
```

## Device Configuration

Armitage hardware profile is defined in `ansible/host_vars/armitage.yml`:

- **Hardware:** Alienware Gaming Laptop
- **CPU:** Intel Core i9-13900HX (24 cores, 32 threads)
- **GPU:** NVIDIA GeForce RTX 4070 (8GB VRAM)
- **Memory:** 32GB DDR5
- **Storage:** 2TB NVMe SSD

## Roles and Capabilities

Armitage is configured with these roles:
- `windows-workstation` - Standard Windows workstation configuration
- `gaming-mode` - Gaming optimizations available
- `cuda-development` - CUDA toolkit for GPU development
- `docker-desktop` - Docker Desktop with WSL2 backend

## Troubleshooting

### WinRM Connection Fails

**From motoko:**
```bash
# Test WinRM connectivity
ansible armitage -i ansible/inventory/hosts.yml -m win_ping -vvv
```

**Common issues:**

1. **WinRM not running:**
   ```powershell
   # On armitage
   Get-Service WinRM
   Start-Service WinRM
   ```

2. **Firewall blocking:**
   ```powershell
   # On armitage
   Get-NetFirewallRule -DisplayName "*WinRM*"
   # Ensure rule exists for Tailscale network (100.64.0.0/10)
   ```

3. **Authentication issues:**
   - Verify password in Ansible Vault: `ansible-vault view ansible/vault.yml`
   - Ensure `ansible_user` matches Windows username
   - Check WinRM authentication settings

### Tailscale Not Connected

```powershell
# On armitage
tailscale status

# If not connected, reconnect
tailscale up --advertise-tags=tag:workstation,tag:windows,tag:gaming
```

### Tags Not Applied

Tags must be approved in Tailscale admin console if not pre-authorized. Check:
- Tailscale admin console for pending device approval
- ACL rules in `miket-infra/infra/tailscale/entra-prod/devices.tf`

### Ansible Can't Resolve Hostname

Ensure MagicDNS is enabled in Tailscale. The inventory uses `.tail2e55fe.ts.net` hostnames which require MagicDNS.

```bash
# From motoko, test DNS resolution
ping armitage.tail2e55fe.ts.net
```

## Security Notes

- **WinRM Authentication:** Uses NTLM authentication over encrypted Tailscale tunnel
- **Password Storage:** Windows passwords stored in Ansible Vault (`ansible/vault.yml`)
- **Network Isolation:** All traffic flows over WireGuard-encrypted Tailscale tunnels
- **ACL Enforcement:** Access controlled by Tailscale ACLs defined in miket-infra

## Next Steps

After successful setup:

1. **Run initial configuration:**
   ```bash
   ansible-playbook -i ansible/inventory/hosts.yml \
     ansible/playbooks/windows-workstation.yml \
     --limit armitage
   ```

2. **Install development tools** (if not done by playbook):
   - Docker Desktop
   - WSL2 with Ubuntu
   - NVIDIA CUDA Toolkit
   - VS Code

3. **Configure device-specific settings:**
   - Review `devices/armitage/config.yml`
   - Run `devices/armitage/Setup-Armitage.ps1` for local optimizations

## Related Documentation

- [Motoko Ansible Control Node Setup](./motoko-ansible-setup.md)
- [Tailscale Integration Guide](../tailscale-integration.md)
- [Windows Workstation Playbook](../../ansible/playbooks/windows-workstation.yml)
- [Ansible Inventory](../../ansible/inventory/hosts.yml)

