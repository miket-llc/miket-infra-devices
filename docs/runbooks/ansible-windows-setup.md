# Ansible Management for Windows Workstations

## Overview

This guide explains how to use Ansible to remotely manage Windows workstations (Armitage, Wintermute) from a Linux control node (motoko) over the Tailscale network.

## Why Ansible for Windows?

### Benefits over Local PowerShell Scripts:
- **Centralized Management**: Control all workstations from motoko
- **Idempotent Operations**: Safe to run multiple times
- **Version Control**: All configurations in Git
- **Scalability**: Same playbooks work for 1 or 100 machines
- **Audit Trail**: Ansible logs all changes
- **No Local Login Required**: Manage remotely via WinRM

### What Ansible Can Do on Windows:
- Install/remove software (MSI, Chocolatey, exe)
- Manage Windows features and roles
- Configure services and scheduled tasks
- Modify registry settings
- Manage files and permissions
- Configure IIS websites
- Apply Windows updates
- Run PowerShell scripts remotely
- Manage local users and groups

## Prerequisites

### On Windows Workstations (Armitage/Wintermute)

1. **Enable WinRM** (Windows Remote Management):
```powershell
# Run as Administrator
Enable-PSRemoting -Force
Set-Item WSMan:\localhost\Service\Auth\Basic -Value $true
Set-Item WSMan:\localhost\Service\AllowUnencrypted -Value $true

# Configure firewall
New-NetFirewallRule -Name "WinRM-HTTP" -DisplayName "WinRM (HTTP)" -Protocol TCP -LocalPort 5985 -Action Allow

# Set service to automatic
Set-Service -Name WinRM -StartupType Automatic
Start-Service -Name WinRM
```

2. **Configure WinRM for Ansible**:
```powershell
# Download and run Ansible's WinRM setup script
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$url = "https://raw.githubusercontent.com/ansible/ansible/devel/examples/scripts/ConfigureRemotingForAnsible.ps1"
$file = "$env:temp\ConfigureRemotingForAnsible.ps1"
Invoke-WebRequest -Uri $url -OutFile $file
powershell.exe -ExecutionPolicy ByPass -File $file
```

### On Linux Control Node (motoko)

1. **Install Ansible and Windows dependencies**:
```bash
# Ubuntu/Debian
sudo apt update
sudo apt install -y ansible python3-pip
pip3 install pywinrm

# Or via pip
pip install ansible pywinrm
```

2. **Create vault for passwords**:
```bash
# Create encrypted vault file
ansible-vault create ~/motoko-devops/ansible/group_vars/windows/vault.yml

# Add passwords (editor will open):
vault_armitage_password: "your-password-here"
vault_wintermute_password: "your-password-here"
```

## Usage Examples

### 1. Test Windows Connectivity
```bash
# From motoko
cd ~/miket-infra-devices
ansible windows -i ansible/inventory/hosts.yml -m win_ping
```

### 2. Run Windows Workstation Playbook
```bash
# Configure all Windows workstations
ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/windows-workstation.yml

# Target specific machine
ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/windows-workstation.yml --limit armitage
```

### 3. Switch Workstation Mode Remotely
```bash
# Switch Armitage to gaming mode
ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/windows-workstation.yml \
  --limit armitage \
  --extra-vars "workstation_mode=gaming"

# Switch to development mode
ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/windows-workstation.yml \
  --limit armitage \
  --extra-vars "workstation_mode=development"
```

### 4. Install Software via Chocolatey
```bash
# Ad-hoc command to install software
ansible armitage -i ansible/inventory/hosts.yml -m win_chocolatey \
  -a "name=steam state=present"

# Install multiple packages
ansible armitage -i ansible/inventory/hosts.yml -m win_chocolatey \
  -a "name=discord,nvidia-geforce-now,epicgameslauncher state=present"
```

### 5. Manage Windows Services
```bash
# Stop Windows Update
ansible armitage -i ansible/inventory/hosts.yml -m win_service \
  -a "name=wuauserv state=stopped start_mode=disabled"

# Start Docker
ansible armitage -i ansible/inventory/hosts.yml -m win_service \
  -a "name=com.docker.service state=started start_mode=auto"
```

### 6. Run PowerShell Commands
```bash
# Get system info
ansible armitage -i ansible/inventory/hosts.yml -m win_shell \
  -a "Get-ComputerInfo | Select-Object CsName, WindowsVersion, OsArchitecture"

# Check GPU
ansible armitage -i ansible/inventory/hosts.yml -m win_shell \
  -a "Get-WmiObject Win32_VideoController | Select-Object Name, DriverVersion"
```

## Ansible vs PowerShell Comparison

| Aspect | Local PowerShell | Ansible |
|--------|-----------------|---------|
| **Execution** | Must log into each machine | Remote from central location |
| **Scalability** | Manual per machine | Automatic for all machines |
| **State Management** | Scripts run regardless | Idempotent (only changes what's needed) |
| **Error Handling** | Script dependent | Built-in retry and error handling |
| **Audit Trail** | Manual logging | Automatic logging and reporting |
| **Credentials** | Interactive or stored locally | Centralized vault encryption |
| **Cross-Platform** | Windows only | Manage Windows, Linux, Mac from one place |

## Mode Management Comparison

### PowerShell (Local):
```powershell
# Must RDP or physically access Armitage
.\Set-WorkstationMode.ps1 -Mode Gaming
```

### Ansible (Remote from motoko):
```bash
# No login required, runs from Linux
ansible-playbook -i inventory/hosts.yml playbooks/switch-mode.yml \
  -e "target_host=armitage target_mode=gaming"
```

## Security Considerations

1. **Use Tailscale**: All WinRM traffic goes over encrypted Tailscale tunnel
2. **Ansible Vault**: Encrypt sensitive data like passwords
3. **Kerberos Option**: For domain environments, use Kerberos instead of NTLM
4. **Certificate Authentication**: Can configure WinRM with SSL certificates

## Best Practices

1. **Hybrid Approach**: 
   - Use Ansible for remote management and configuration drift prevention
   - Keep PowerShell scripts for local troubleshooting and quick fixes

2. **Testing**:
   - Test playbooks with `--check` flag first
   - Use `--diff` to see what will change

3. **Organization**:
   - Group common tasks into roles
   - Use variables for environment-specific settings
   - Tag tasks for selective execution

## Troubleshooting

### WinRM Connection Issues
```bash
# Test WinRM from Linux
curl -v http://armitage.tailnet-name.ts.net:5985/wsman

# Debug Ansible connection
ansible armitage -i inventory/hosts.yml -m win_ping -vvv
```

### Common Errors
- **401 Unauthorized**: Check username/password in vault
- **Connection refused**: WinRM not running or firewall blocking
- **Certificate error**: Add `ansible_winrm_server_cert_validation: ignore`

## Next Steps

1. Set up WinRM on Armitage and Wintermute
2. Configure Ansible on motoko
3. Test connectivity with win_ping
4. Run the windows-workstation playbook
5. Create custom playbooks for your specific needs