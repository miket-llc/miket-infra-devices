# Armitage vLLM Container Troubleshooting

## Quick Check Script

If the vLLM container is not running on armitage, you can run this script directly on armitage:

```powershell
# Copy the script to armitage, then run:
.\Check-Start-VLLM-Armitage.ps1
```

Or run it remotely via Ansible (when connectivity is available):

```bash
cd /home/mdt/miket-infra-devices/ansible
ansible armitage -i inventory/hosts.yml -m win_shell -a 'powershell -ExecutionPolicy Bypass -File C:\Users\mdt\dev\armitage\scripts\Check-Start-VLLM-Armitage.ps1'
```

## Manual Checks

### 1. Check Docker Service
```powershell
Get-Service com.docker.service
# Should show Status: Running
```

### 2. Check Container Status
```powershell
# All containers
docker ps -a

# vLLM container specifically
docker ps -a --filter name=vllm-armitage

# Running containers
docker ps
```

### 3. Check if Scripts Were Deployed
```powershell
Test-Path "C:\Users\mdt\dev\armitage\scripts\Start-VLLM.ps1"
# Should return True
```

### 4. Start Container Manually

If scripts are deployed:
```powershell
cd C:\Users\mdt\dev\armitage\scripts
.\Start-VLLM.ps1 -Action Start
```

If container exists but is stopped:
```powershell
docker start vllm-armitage
```

## Common Issues

### Container Not Found
**Symptom:** `docker ps -a` shows no vLLM container

**Solution:** Deployment may not have completed. Run:
```bash
# From motoko
cd /home/mdt/miket-infra-devices/ansible
ansible-playbook -i inventory/hosts.yml playbooks/armitage-vllm-deploy-scripts.yml --limit armitage
```

### Container Exists But Not Running
**Symptom:** Container shows in `docker ps -a` but not in `docker ps`

**Solution:**
```powershell
# Check why it stopped
docker logs vllm-armitage

# Start it
docker start vllm-armitage

# Or use the script
.\Start-VLLM.ps1 -Action Start
```

### Docker Service Not Running
**Symptom:** `Get-Service com.docker.service` shows Stopped

**Solution:**
1. Start Docker Desktop application
2. Wait for it to fully initialize (check system tray)
3. Verify: `Get-Service com.docker.service` should show Running

### Scripts Not Deployed
**Symptom:** `Test-Path "C:\Users\mdt\dev\armitage\scripts\Start-VLLM.ps1"` returns False

**Solution:** Run the deployment playbook (see above)

## Deployment Status

To check if deployment completed:
```powershell
# Check scripts
Test-Path "C:\Users\mdt\dev\armitage\scripts\Start-VLLM.ps1"
Test-Path "C:\Users\mdt\dev\armitage\config.yml"

# Check config
Test-Path "C:\ProgramData\ArmitageMode\vllm_config.json"
```

## Starting the Container

### Method 1: Using Start-VLLM.ps1 (Recommended)
```powershell
cd C:\Users\mdt\dev\armitage\scripts
.\Start-VLLM.ps1 -Action Start
```

### Method 2: Direct Docker Command
```powershell
# Check config.yml for exact parameters
docker run -d --name vllm-armitage --gpus all -p 8000:8000 --restart unless-stopped --shm-size 4g vllm/vllm-openai:latest --model Qwen/Qwen2.5-7B-Instruct-AWQ --max-model-len 16384 --max-num-seqs 1 --gpu-memory-utilization 0.85 --served-model-name qwen2.5-7b-armitage --port 8000 --host 0.0.0.0
```

## Verifying Container is Working

```powershell
# Check container is running
docker ps --filter name=vllm-armitage

# Check logs
docker logs vllm-armitage --tail 50

# Test API
Invoke-WebRequest -Uri "http://localhost:8000/v1/models" -UseBasicParsing
```

## API Endpoints

Once running, the API is available at:
- Local: `http://localhost:8000/v1`
- Remote: `http://armitage.pangolin-vega.ts.net:8000/v1`

Test with:
```bash
curl http://armitage.pangolin-vega.ts.net:8000/v1/models
```



