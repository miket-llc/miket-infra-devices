# Wintermute Windows Workstation Setup Runbook

This runbook guides you through setting up Wintermute (Windows 11 Pro desktop) for Ansible management from the motoko control node, including vLLM serving capabilities.

## Prerequisites

- Wintermute is running Windows 11 Pro
- Administrator access on wintermute
- Tailscale account access (via miket-infra ACLs)
- motoko is already configured as Ansible control node
- NVIDIA drivers installed (latest version)

## Quick Setup

### One-Command Bootstrap

From wintermute (as Administrator):

```powershell
# Clone repository if needed
git clone https://github.com/miket-llc/miket-infra-devices.git C:\Users\$env:USERNAME\dev\miket-infra-devices
cd C:\Users\$env:USERNAME\dev\miket-infra-devices

# Run bootstrap script
.\scripts\bootstrap-wintermute.ps1
```

This script will:
1. Create mdt automation account
2. Configure WinRM for Ansible management
3. Configure Tailscale with proper tags (`tag:workstation,tag:windows,tag:gpu_12gb`)
4. Verify connectivity

## Manual Setup Steps

### Step 1: Bootstrap for Ansible

Run the bootstrap script (see Quick Setup above) or manually:

#### Create mdt Automation Account

```powershell
# Run as Administrator
.\scripts\bootstrap-windows-automation-account.ps1
```

#### Configure WinRM

```powershell
# Run as Administrator
.\scripts\Setup-WinRM.ps1
```

#### Configure Tailscale

```powershell
# Run as Administrator
.\scripts\Setup-Tailscale.ps1 -DeviceName WINTERMUTE
```

**Required Tags:**
- `tag:workstation` - Identifies as workstation device
- `tag:windows` - Windows OS family
- `tag:gpu_12gb` - GPU with 12GB+ VRAM (RTX 4070 Super)

### Step 2: WSL2 and Ubuntu 24.04 Setup

**Manual steps (for observability):**

1. **Unregister old Ubuntu 22.04 (if exists):**
   ```powershell
   wsl --unregister Ubuntu-22.04
   ```

2. **Install Ubuntu 24.04:**
   ```powershell
   wsl --install -d Ubuntu-24.04
   ```

3. **Complete Ubuntu first-run setup:**
   ```powershell
   wsl -d Ubuntu-24.04
   ```
   - Create user account when prompted
   - Set password

4. **Verify WSL2:**
   ```powershell
   wsl --list --verbose
   ```
   Should show Ubuntu-24.04 with VERSION 2

### Step 3: NVIDIA Container Toolkit (Manual - Recommended)

**Why manual:** This requires running commands inside WSL2 and benefits from observability.

**Inside WSL2 Ubuntu 24.04:**

```bash
# Enter WSL2
wsl -d Ubuntu-24.04

# Update packages
sudo apt-get update

# Install prerequisites
sudo apt-get install -y curl ca-certificates gnupg lsb-release

# Add NVIDIA Container Toolkit repository
distribution=$(grep VERSION_ID /etc/os-release | cut -d '"' -f 2 | cut -d '.' -f 1,2)
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
curl -s -L https://nvidia.github.io/libnvidia-container/${distribution}/libnvidia-container.list | \
    sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
    sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

# Install NVIDIA Container Toolkit
sudo apt-get update
sudo apt-get install -y nvidia-container-toolkit

# Configure Docker to use NVIDIA runtime
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker

# Verify installation
docker run --rm --gpus all nvidia/cuda:12.0.0-base-ubuntu24.04 nvidia-smi
```

**Expected output:** Should show NVIDIA GPU information from inside the container.

### Step 4: Verify Setup

**On wintermute:**

```powershell
# Check WinRM status
Get-Service WinRM

# Check Tailscale status
tailscale status

# Check WSL2
wsl --list --verbose

# Check Docker Desktop
docker version

# Check NVIDIA drivers
nvidia-smi
```

**From motoko:**

```bash
# Test WinRM connectivity
ansible wintermute -i ~/miket-infra-devices/ansible/inventory/hosts.yml -m win_ping
```

Expected output:
```
wintermute | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
```

## Running Ansible Playbooks

### Initial Workstation Configuration

```bash
# From motoko
cd ~/miket-infra-devices
ansible-playbook -i ansible/inventory/hosts.yml \
  ansible/playbooks/windows-workstation.yml \
  --limit wintermute
```

### vLLM Setup

```bash
# Deploy vLLM scripts and configuration
ansible-playbook -i ansible/inventory/hosts.yml \
  ansible/playbooks/wintermute-vllm-setup.yml \
  --limit wintermute \
  --ask-vault-pass
```

This playbook will:
- Ensure Docker Desktop is running
- Deploy vLLM management scripts to `C:\Users\mdt\dev\wintermute\scripts\`
- Create vLLM configuration
- Set up scheduled task for auto mode switching

## Device Configuration

Wintermute hardware profile is defined in `devices/wintermute/config.yml`:

- **Hardware:** Desktop Workstation
- **CPU:** Intel Core i9 (high-performance)
- **GPU:** NVIDIA GeForce RTX 4070 Super (12GB VRAM)
- **Use Cases:** Development, gaming, streaming, flight sims, vLLM serving

## vLLM Management

### Manual Control

```powershell
# Start vLLM container
.\devices\wintermute\scripts\Start-VLLM.ps1 -Action Start

# Stop vLLM container
.\devices\wintermute\scripts\Start-VLLM.ps1 -Action Stop

# Check status
.\devices\wintermute\scripts\Start-VLLM.ps1 -Action Status

# View logs
.\devices\wintermute\scripts\Start-VLLM.ps1 -Action Logs
```

### Auto Mode Switching

Manual mode switching only (auto-switcher removed per CEO directive):
- **Stops vLLM** when workstation is in use (gaming, streaming, etc.)
- **Starts vLLM** when system is idle

```powershell
# Use Start-VLLM.ps1 for manual container control
# Use Set-WorkstationMode.ps1 for mode switching
```

## Troubleshooting

### WinRM Connection Fails

See [Armitage Setup Runbook](./armitage-setup.md#troubleshooting) for WinRM troubleshooting.

### WSL2 Not Working

```powershell
# Check WSL status
wsl --status

# Restart WSL
wsl --shutdown
wsl -d Ubuntu-24.04

# Check if Virtual Machine Platform is enabled
Get-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform
```

### NVIDIA Container Toolkit Issues

**Inside WSL2:**

```bash
# Check if toolkit is installed
dpkg -l | grep nvidia-container-toolkit

# Check Docker daemon config
cat /etc/docker/daemon.json

# Restart Docker
sudo systemctl restart docker

# Test GPU access
docker run --rm --gpus all nvidia/cuda:12.0.0-base-ubuntu24.04 nvidia-smi
```

### Docker GPU Not Available

1. Ensure Docker Desktop is using WSL2 backend (Settings > General > Use WSL 2)
2. Verify NVIDIA Container Toolkit is installed in WSL2
3. Check Docker Desktop can see GPU:
   ```powershell
   docker run --rm --gpus all nvidia/cuda:12.0.0-base-ubuntu24.04 nvidia-smi
   ```

### vLLM Container Won't Start

1. Check Docker Desktop is running
2. Verify GPU is available: `nvidia-smi`
3. Check container logs: `.\devices\wintermute\scripts\Start-VLLM.ps1 -Action Logs`
4. Ensure NVIDIA Container Toolkit is configured in WSL2

## Security Notes

- **WinRM Authentication:** Uses NTLM authentication over encrypted Tailscale tunnel
- **Password Storage:** Windows passwords stored in Ansible Vault (`ansible/group_vars/windows/vault.yml`)
- **Network Isolation:** All traffic flows over WireGuard-encrypted Tailscale tunnels
- **ACL Enforcement:** Access controlled by Tailscale ACLs defined in miket-infra

## Related Documentation

- [Motoko Ansible Control Node Setup](./motoko-ansible-setup.md)
- [Armitage Setup Runbook](./armitage-setup.md) (similar Windows workstation)
- [Armitage vLLM Setup](./armitage-vllm.md) (similar vLLM configuration)
- [Tailscale Integration Guide](../tailscale-integration.md)
- [Windows Workstation Playbook](../../ansible/playbooks/windows-workstation.yml)

