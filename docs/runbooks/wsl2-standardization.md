# WSL2 Standardization for Windows Workstations

## Overview

All Windows workstations should use WSL2 as the Docker Desktop backend for consistency and better GPU support.

## Current Status

- **armitage**: ✅ WSL2 installed and configured
- **wintermute**: ⚠️ WSL2 features enabled, reboot required to complete installation

## Benefits of Standardizing on WSL2

1. **Consistency**: All Windows workstations use the same Docker backend
2. **Better GPU Support**: NVIDIA Container Toolkit works better with WSL2
3. **Performance**: WSL2 provides better performance for Linux containers
4. **Easier Management**: Consistent configuration across all hosts
5. **Documentation Alignment**: Matches documented standard (`backend: wsl2`)

## Standardization Process

### Step 1: Install WSL2

Run the WSL2 configuration playbook:

```bash
ansible-playbook -i inventory/hosts.yml playbooks/configure-wsl2-windows.yml --limit wintermute
```

This will:
- Enable WSL feature
- Enable Virtual Machine Platform feature
- Set WSL2 as default version
- Install Ubuntu distribution
- Configure Docker Desktop to use WSL2 backend

### Step 2: Reboot Required

After running the playbook, **reboot the workstation** to complete WSL2 installation.

### Step 3: Verify Installation

After reboot, verify WSL2 is working:

```bash
# Check WSL status
ansible-playbook -i inventory/hosts.yml playbooks/windows-vllm-test.yml --limit wintermute

# Or manually check
ansible wintermute -i inventory/hosts.yml -m win_shell -a "wsl --list --verbose"
```

### Step 4: Install NVIDIA Container Toolkit (if needed)

After WSL2 is installed, install NVIDIA Container Toolkit:

```bash
ansible-playbook -i inventory/hosts.yml playbooks/fix-nvidia-repo-windows.yml --limit wintermute
```

## Configuration Files

### Group Variables

**File:** `ansible/group_vars/windows_workstations/main.yml`

```yaml
wsl2:
  enabled: true
  default_distro: Ubuntu
  nvidia_toolkit_required: true

docker_desktop:
  backend: wsl2
```

### Host Variables

Each host should have `vllm` configuration in `host_vars/{hostname}.yml`:

```yaml
vllm:
  container_name: "vllm-{hostname}"
  port: 8000
  # ... other vLLM settings
```

## Verification

After standardization, verify:

1. **WSL2 Status**: `wsl --list --verbose` shows Ubuntu distribution
2. **Docker Backend**: Docker Desktop settings show WSL2 backend enabled
3. **GPU Access**: `docker run --rm --gpus all nvidia/cuda:12.0.0-base-ubuntu22.04 nvidia-smi` works
4. **vLLM Container**: Container runs and responds to API calls

## Troubleshooting

### WSL2 Not Installing After Reboot

If Ubuntu doesn't install after reboot:

```bash
# Manually install Ubuntu
ansible wintermute -i inventory/hosts.yml -m win_shell -a "wsl --install -d Ubuntu-22.04"
```

### Docker Desktop Not Using WSL2

Check Docker Desktop settings:
- Settings → General → Use WSL 2 based engine (should be checked)

Or configure via Ansible:
```bash
ansible-playbook -i inventory/hosts.yml playbooks/configure-wsl2-windows.yml --limit wintermute
```

### NVIDIA Container Toolkit Issues

If GPU access doesn't work after WSL2 installation:

```bash
# Fix repository configuration
ansible-playbook -i inventory/hosts.yml playbooks/fix-nvidia-repo-windows.yml --limit wintermute

# Install toolkit in WSL2
ansible wintermute -i inventory/hosts.yml -m win_shell -a "wsl -d Ubuntu -- bash -c 'sudo apt-get update && sudo apt-get install -y nvidia-container-toolkit'"
```

## Migration Notes

When migrating from Hyper-V backend to WSL2:

1. **No data loss**: Docker containers and images are preserved
2. **Reboot required**: Windows features need reboot to activate
3. **Docker Desktop**: Will automatically switch to WSL2 backend after configuration
4. **vLLM containers**: Will continue working after backend switch

## Post-Migration Checklist

- [ ] WSL2 features enabled
- [ ] Ubuntu distribution installed
- [ ] Docker Desktop using WSL2 backend
- [ ] NVIDIA Container Toolkit installed (if GPU support needed)
- [ ] GPU access working from Docker containers
- [ ] vLLM container running and responding
- [ ] Test playbook passes all checks

