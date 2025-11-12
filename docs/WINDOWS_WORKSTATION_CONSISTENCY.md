# Windows Workstation Configuration Consistency

## Overview

This document defines the consistent configuration approach for Windows workstations with Docker Desktop (armitage and wintermute).

## Shared Configuration

### Group Variables
**File:** `ansible/group_vars/windows_workstations/main.yml`

All Windows workstations share:
- User account: `mdt` (local account only, no Microsoft account)
- Docker Desktop with WSL2 backend
- vLLM serving capabilities
- Auto mode switching
- RDP with Group Policy configuration
- Same script deployment paths

### Inventory Structure
**File:** `ansible/inventory/hosts.yml`

Windows workstations are grouped under `windows_workstations`:
```yaml
windows:
  children:
    windows_workstations:
      hosts:
        wintermute:
        armitage:
```

This allows targeting all Windows workstations with:
```bash
ansible-playbook playbook.yml --limit windows_workstations
```

## Consistent Paths

All Windows workstations use the same path structure:
- Scripts: `C:\Users\mdt\dev\{hostname}\scripts\`
- Config: `C:\ProgramData\{Hostname}Mode\`
- Docker config: `C:\Users\mdt\.docker\`

Examples:
- armitage: `C:\Users\mdt\dev\armitage\scripts\`
- wintermute: `C:\Users\mdt\dev\wintermute\scripts\`

## Consistent Configuration Files

### 1. Docker Desktop
- Credential store disabled: `"credsStore": ""`
- WSL2 backend enabled
- NVIDIA Container Toolkit in WSL2
- Same Docker config for both machines

### 2. vLLM Configuration
Each machine has device-specific settings in `devices/{hostname}/config.yml`:
- Model (different per machine based on GPU)
- VRAM-specific settings
- Container name: `vllm-{hostname}`

But shares:
- Port: 8000
- Image: vllm/vllm-openai:latest
- Auto-switch: enabled
- Check interval: 5 minutes

### 3. RDP Configuration
Both machines have identical RDP configuration:
- Group Policy enabled (prevents toggle from reverting)
- Network Level Authentication enabled
- Firewall restricted to Tailscale subnet (100.64.0.0/10)
- All administrators have RDP access

### 4. PowerShell Scripts
Same scripts deployed to both machines:
- `Start-VLLM.ps1` - Start/stop/restart container
- `Auto-ModeSwitcher.ps1` - Automatic mode switching
- `Set-WorkstationMode.ps1` - Manual mode switching

## Device-Specific Configuration

Only these differ between armitage and wintermute:

| Setting | Armitage | Wintermute |
|---------|----------|------------|
| GPU | RTX 4070 (8GB) | RTX 4070 Super (12GB) |
| Model | Qwen/Qwen2.5-7B-Instruct-AWQ | casperhansen/llama-3-8b-instruct-awq |
| Max Model Len | 16384 | 9000 |
| Form Factor | Laptop | Desktop |
| Location | Mobile | Fixed |

## Playbooks

All playbooks targeting Windows workstations should use:
- `hosts: windows_workstations` (for all)
- `hosts: armitage` or `hosts: wintermute` (for specific machine)
- `--limit windows_workstations` (to target the group)

### Key Playbooks
1. `configure-windows-rdp.yml` - RDP configuration (all Windows workstations)
2. `windows-vllm-deploy.yml` - vLLM deployment (uses role: windows-vllm-deploy)
3. `remote_server.yml` - Remote desktop setup (all workstations by OS)

## Deployment Commands

### Deploy to all Windows workstations
```bash
# RDP configuration
ansible-playbook -i inventory/hosts.yml playbooks/configure-windows-rdp.yml

# vLLM deployment
ansible-playbook -i inventory/hosts.yml playbooks/windows-vllm-deploy.yml
```

### Deploy to specific workstation
```bash
# RDP configuration
ansible-playbook -i inventory/hosts.yml playbooks/configure-windows-rdp.yml --limit armitage

# vLLM deployment
ansible-playbook -i inventory/hosts.yml playbooks/windows-vllm-deploy.yml -e "target_hosts=armitage"
```

## User Account Configuration

### Simplified Approach
- **Only use:** `mdt` local account
- **No longer using:** Microsoft accounts (mdt_@msn.com)
- **Reason:** Simpler automation, no credential helper issues

### Account Setup
The `mdt` account is:
- Member of Administrators group
- Member of Remote Desktop Users group
- Used for both automation and personal use
- Password stored in ansible vault

## Validation

To verify consistency:
```bash
# Check both machines have same configuration
ansible windows_workstations -i inventory/hosts.yml -m win_shell -a 'Test-Path "C:\Users\mdt\dev\{{ inventory_hostname }}\scripts\Start-VLLM.ps1"'

# Verify Docker config
ansible windows_workstations -i inventory/hosts.yml -m win_shell -a 'Get-Content C:\Users\mdt\.docker\config.json'

# Check RDP configuration
ansible-playbook -i inventory/hosts.yml playbooks/diagnose-rdp.yml --limit windows_workstations
```

## Benefits of This Approach

1. **Simplified user management** - One local account, no Microsoft account complexity
2. **Consistent paths** - Same structure on both machines
3. **Shared configuration** - Common settings in group_vars
4. **Device-specific overrides** - GPU/model differences in host_vars or device config.yml
5. **Easier maintenance** - Changes apply to all Windows workstations
6. **Better automation** - No credential helper issues with Docker

## Migration Notes

When migrating from Microsoft account (`mdt_@msn.com`) to local account (`mdt`):
1. Delete Microsoft account from Windows machine
2. Ensure local `mdt` account exists and is administrator
3. Redeploy configurations via Ansible
4. All paths automatically use `C:\Users\mdt\` instead of `C:\Users\mdt_\`



