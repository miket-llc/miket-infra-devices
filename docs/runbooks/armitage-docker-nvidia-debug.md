# Armitage Docker + NVIDIA Debugging Guide

## Current Situation

You're trying to run vLLM on Armitage (Windows 11) using Docker Desktop with NVIDIA GPU support through WSL2. The issues are:
1. Docker Desktop is running but hammering the CPU
2. From motoko, it doesn't look like it's working properly
3. NVIDIA Container Toolkit doesn't seem to be working properly

## Quick Debugging

Run the debugging script locally on Armitage:

```powershell
cd C:\Users\mdt\dev\armitage\scripts
.\Debug-DockerNvidia.ps1
```

This will check:
- ✅ Windows NVIDIA GPU availability
- ✅ WSL2 installation and distributions
- ✅ Docker Desktop service and process
- ✅ Docker CLI accessibility
- ✅ Docker context and backend
- ✅ NVIDIA Container Toolkit in WSL2
- ✅ Docker GPU support (test container)
- ✅ vLLM container status

## Common Issues and Fixes

### Issue 1: NVIDIA Container Toolkit Not Installed

**Symptom**: Docker containers can't access GPU, `--gpus all` fails

**Fix**: Run the installer script:
```powershell
.\Install-NvidiaContainerToolkit.ps1
```

Then restart Docker Desktop completely.

### Issue 2: Docker Desktop High CPU Usage

**Symptom**: Docker Desktop process using >50% CPU constantly

**Fixes**:
1. Restart Docker Desktop completely (quit, wait, restart)
2. Restart WSL2: `wsl --shutdown` then restart Docker Desktop
3. Check Docker Desktop Settings > Resources > Advanced (reduce CPU limit if set)
4. Update Docker Desktop to latest version
5. Check for stuck containers: `docker ps -a` and remove unused ones

### Issue 3: GPU Not Visible in WSL2

**Symptom**: `nvidia-smi` fails in WSL2

**Fix**: Install NVIDIA WSL2 CUDA drivers:
1. Download from: https://developer.nvidia.com/cuda/wsl
2. Install on Windows
3. Restart WSL2: `wsl --shutdown`
4. Restart Docker Desktop

### Issue 4: Docker Not Using WSL2 Backend

**Symptom**: Docker info doesn't show WSL2 backend

**Fix**:
1. Docker Desktop Settings > General
2. Ensure "Use WSL 2 based engine" is checked
3. Docker Desktop Settings > Resources > WSL Integration
4. Enable integration for your Ubuntu distro
5. Restart Docker Desktop

## Manual Testing Steps

### 1. Test Docker GPU Support

```powershell
docker run --rm --gpus all nvidia/cuda:11.0.3-base-ubuntu20.04 nvidia-smi
```

Should show GPU information. If it fails, NVIDIA Container Toolkit isn't working.

### 2. Test vLLM Container

```powershell
cd C:\Users\mdt\dev\armitage\scripts
.\Start-VLLM.ps1 -Action Start
.\Start-VLLM.ps1 -Action Status
.\Start-VLLM.ps1 -Action Logs
```

### 3. Check from motoko

From motoko (Linux control node), test the API:

```bash
curl http://armitage.pangolin-vega.ts.net:8000/health
```

## What the Ansible Playbook Does

The `armitage-vllm-setup.yml` playbook:
1. Ensures WSL2 is installed
2. Installs Docker Desktop via Chocolatey
3. Starts Docker Desktop service
4. Waits for Docker to be ready
5. Deploys PowerShell scripts
6. Creates configuration files
7. Sets up scheduled task for auto-switching

**What it DOESN'T do**: Install NVIDIA Container Toolkit in WSL2. This must be done manually or via the installer script.

## Files Created

- `devices/armitage/scripts/Debug-DockerNvidia.ps1` - Comprehensive debugging script
- `devices/armitage/scripts/Install-NvidiaContainerToolkit.ps1` - Automated installer

## Next Steps

1. **Run the debug script** to see current state
2. **Fix critical issues** identified by the debug script
3. **Install NVIDIA Container Toolkit** if missing
4. **Restart Docker Desktop** after any changes
5. **Test GPU support** with the test container
6. **Start vLLM** and verify it's working
7. **Test from motoko** to verify remote access

## Troubleshooting from motoko

If you're debugging from motoko, you can:

```bash
# SSH into armitage
ssh armitage

# Run the debug script
cd C:\Users\mdt\dev\armitage\scripts
powershell -ExecutionPolicy Bypass -File .\Debug-DockerNvidia.ps1

# Check Docker status
docker ps
docker ps -a

# Check GPU in WSL2
wsl -d Ubuntu-22.04 -- nvidia-smi

# Check Docker Desktop process
Get-Process "Docker Desktop" | Select-Object CPU,WorkingSet
```

## References

- [NVIDIA Container Toolkit Docs](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html)
- [Docker Desktop WSL2 Backend](https://docs.docker.com/desktop/wsl/)
- [NVIDIA WSL2 CUDA Drivers](https://developer.nvidia.com/cuda/wsl)
- [vLLM Documentation](https://docs.vllm.ai/)



