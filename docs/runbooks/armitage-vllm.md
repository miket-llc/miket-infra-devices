# Armitage vLLM Setup and Auto-Switching

This document describes how Armitage is configured as a vLLM inference node with automatic mode switching between workstation use and LLM serving.

## Overview

Armitage automatically switches between two modes:
- **Workstation Mode**: When the system is in use (user active, GPU in use by applications)
- **LLM Serving Mode**: When the system is idle (automatically starts vLLM container)

## Architecture

### Components

1. **Auto-ModeSwitcher.ps1**: Monitors system activity and switches modes automatically
2. **Start-VLLM.ps1**: Manages vLLM Docker container lifecycle
3. **Set-WorkstationMode.ps1**: Applies Windows optimizations for each mode
4. **Scheduled Task**: Runs Auto-ModeSwitcher periodically

### Mode Detection

The auto-switcher monitors:
- **User Activity**: Active logon sessions, running applications (Chrome, VS Code, Steam, etc.)
- **GPU Usage**: Non-Docker processes using the GPU
- **Idle Time**: System idle threshold (default: 5 minutes)

### Mode Behavior

**Workstation Mode** (when in use):
- Stops vLLM container to free GPU resources
- Applies productivity/development optimizations
- Ensures full GPU availability for user applications

**LLM Serving Mode** (when idle):
- Starts vLLM container with GPU acceleration
- Applies development mode optimizations
- Makes LLM API available at `http://armitage.pangolin-vega.ts.net:8000`

## Setup

### Initial Deployment

From the Ansible control node (motoko):

**Recommended: Use the deployment script (with enhanced observability):**

```bash
cd /path/to/miket-infra-devices
./scripts/deploy-armitage-vllm.sh
```

**Or manually:**

```bash
cd ansible
ansible-playbook -i inventory/hosts.yml \
  playbooks/armitage-vllm-setup.yml \
  --limit armitage \
  --ask-vault-pass \
  -v
```

**Key improvements for observability:**
- WinRM timeouts configured (600s) to prevent connection drops during long operations
- Real-time progress output with timestamps
- Enhanced Docker wait task with progress indicators
- Deployment duration tracking

This will:
1. Ensure Docker Desktop is installed and running
2. Deploy PowerShell scripts to Armitage
3. Create configuration files
4. Set up scheduled task for auto-switching

### Manual Setup (if needed)

On Armitage:

```powershell
# Navigate to scripts directory
cd C:\Users\mdt\dev\armitage\scripts

# Test vLLM script
.\Start-VLLM.ps1 -Action Status

# Start vLLM manually
.\Start-VLLM.ps1 -Action Start

# Check auto-switcher
.\Auto-ModeSwitcher.ps1
```

## Usage

### Manual Mode Control

```powershell
# Force workstation mode (stops vLLM)
.\Auto-ModeSwitcher.ps1 -ForceMode workstation

# Force LLM mode (starts vLLM)
.\Auto-ModeSwitcher.ps1 -ForceMode llm

# Enable auto mode (default)
.\Auto-ModeSwitcher.ps1 -ForceMode auto
```

### vLLM Container Management

```powershell
# Start vLLM
.\Start-VLLM.ps1 -Action Start

# Stop vLLM
.\Start-VLLM.ps1 -Action Stop

# Restart vLLM
.\Start-VLLM.ps1 -Action Restart

# Check status
.\Start-VLLM.ps1 -Action Status

# View logs
.\Start-VLLM.ps1 -Action Logs
```

### API Access

When vLLM is running, the API is available at:
- **Local**: `http://localhost:8000`
- **Tailnet**: `http://armitage.pangolin-vega.ts.net:8000`

Test the API:
```bash
# Health check
curl http://armitage.pangolin-vega.ts.net:8000/health

# Chat completion
curl http://armitage.pangolin-vega.ts.net:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "mistralai/Mistral-7B-Instruct-v0.2",
    "messages": [{"role": "user", "content": "Hello!"}]
  }'
```

## Configuration

### vLLM Settings

Edit `C:\ProgramData\ArmitageMode\vllm_config.json`:

```json
{
  "model": "mistralai/Mistral-7B-Instruct-v0.2",
  "port": 8000,
  "container_name": "vllm-armitage",
  "image": "vllm/vllm-openai:latest",
  "auto_switch": true
}
```

Or update `devices/armitage/config.yml` and redeploy.

### Auto-Switcher Settings

Edit `Auto-ModeSwitcher.ps1` parameters:
- `$CheckInterval`: How often to check (default: 60 seconds)
- `$IdleThreshold`: Minutes of inactivity before LLM mode (default: 5)

### Scheduled Task

The scheduled task runs:
- On boot
- On user logon
- Every 5 minutes (configurable)
- As SYSTEM user (highest privileges)

View/modify:
```powershell
# View task
Get-ScheduledTask -TaskName "Armitage Auto Mode Switcher"

# Disable auto-switching
Disable-ScheduledTask -TaskName "Armitage Auto Mode Switcher"

# Enable auto-switching
Enable-ScheduledTask -TaskName "Armitage Auto Mode Switcher"
```

## Monitoring

### Logs

Auto-switcher logs: `%LOCALAPPDATA%\ArmitageMode\auto_mode_switcher.log`

Mode state: `%LOCALAPPDATA%\ArmitageMode\current_mode.json`

### Status Checks

```powershell
# Check current mode
Get-Content "$env:LOCALAPPDATA\ArmitageMode\current_mode.json" | ConvertFrom-Json

# Check vLLM container
docker ps --filter "name=vllm-armitage"

# Check GPU usage
& "${env:ProgramFiles}\NVIDIA Corporation\NVSMI\nvidia-smi.exe"
```

## Troubleshooting

### WinRM Timeout Issues

If you encounter WinRM timeouts during deployment:

**Symptoms:**
- Playbook hangs or fails with "WinRM operation timeout" errors
- Connection drops during long-running tasks (especially Docker wait)
- Tasks fail with "Operation timed out" messages

**Solution:**

WinRM timeout settings are now configured in `ansible/group_vars/windows/main.yml`:
- `ansible_winrm_read_timeout: 600` (10 minutes)
- `ansible_winrm_operation_timeout: 600` (10 minutes)

**Verify configuration:**
```bash
# Check that timeout settings are loaded
ansible armitage -i ansible/inventory/hosts.yml -m debug -a "var=ansible_winrm_read_timeout"
```

**If timeouts persist:**
1. Check WinRM service on Armitage:
   ```powershell
   Get-Service WinRM
   winrm get winrm/config
   ```

2. Verify Tailscale connectivity:
   ```bash
   # From motoko
   ping armitage.pangolin-vega.ts.net
   ```

3. Test WinRM connection:
   ```bash
   ansible armitage -i ansible/inventory/hosts.yml -m win_ping -vvv
   ```

4. Increase timeouts further if needed (edit `ansible/group_vars/windows/main.yml`)

### vLLM Container Won't Start

1. **Check Docker Desktop**:
   ```powershell
   Get-Service com.docker.service
   docker version
   ```

2. **Check GPU availability**:
   ```powershell
   & "${env:ProgramFiles}\NVIDIA Corporation\NVSMI\nvidia-smi.exe"
   ```

3. **Check container logs**:
   ```powershell
   .\Start-VLLM.ps1 -Action Logs
   ```

### Auto-Switcher Not Working

1. **Check scheduled task**:
   ```powershell
   Get-ScheduledTask -TaskName "Armitage Auto Mode Switcher"
   ```

2. **Check logs**:
   ```powershell
   Get-Content "$env:LOCALAPPDATA\ArmitageMode\auto_mode_switcher.log" -Tail 50
   ```

3. **Run manually**:
   ```powershell
   .\Auto-ModeSwitcher.ps1
   ```

### GPU Not Available to Docker

1. Ensure WSL2 backend is enabled in Docker Desktop
2. Install NVIDIA Container Toolkit in WSL2:
   ```bash
   # In WSL2 Ubuntu
   distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
   curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add -
   curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | sudo tee /etc/apt/sources.list.d/nvidia-docker.list
   sudo apt-get update && sudo apt-get install -y nvidia-container-toolkit
   sudo systemctl restart docker
   ```

## Performance Considerations

### GPU Memory

- RTX 4070 has 8GB VRAM
- Mistral-7B-Instruct requires ~7GB VRAM
- When workstation mode is active, vLLM stops to free GPU

### CPU/RAM

- Auto-switcher runs every 60 seconds (low overhead)
- vLLM container uses GPU primarily, minimal CPU impact when idle

### Network

- API accessible over Tailnet
- No external exposure required (Tailscale handles security)

## Related Documentation

- [Armitage Runbook](../runbooks/armitage.md)
- [Windows Workstation Setup](../ansible-windows-setup.md)
- [vLLM Documentation](https://docs.vllm.ai/)

