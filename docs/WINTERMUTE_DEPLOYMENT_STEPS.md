# Wintermute Model Fix - Deployment Complete ✅

## Configuration Fixed

All configuration files have been updated to use **Llama 3.1 8B Instruct AWQ** consistently:

✅ `devices/wintermute/config.yml`  
✅ `devices/wintermute/scripts/Start-VLLM.ps1`  
✅ `devices/wintermute/scripts/vllm.sh`  
✅ `ansible/roles/litellm_proxy/templates/litellm.config.yaml.j2`  

## Deployment Instructions

**IMPORTANT:** Run all commands from the `ansible/` directory so group_vars load correctly.

### Step 1: Deploy Wintermute vLLM Scripts

```bash
cd ~/miket-infra-devices/ansible

ansible-playbook -i inventory/hosts.yml \
  playbooks/remote/wintermute-vllm-deploy-scripts.yml \
  --limit wintermute \
  --ask-vault-pass
```

This updates the configuration file on Wintermute with the correct model. The playbook is non-destructive and won't restart running containers.

### Step 2: Restart vLLM Container on Wintermute

After deployment, restart the container to use the new model. You can do this:

**Option A: Via PowerShell on Wintermute (Recommended)**
```powershell
cd C:\Users\mdt\dev\wintermute\scripts
.\Start-VLLM.ps1 -Action Restart
```

**Option B: Via Ansible (if WinRM is configured)**
```bash
cd ~/miket-infra-devices/ansible
ansible wintermute -i inventory/hosts.yml -m win_shell \
  -a "cd C:\Users\mdt\dev\wintermute\scripts; .\Start-VLLM.ps1 -Action Restart" \
  --ask-vault-pass
```

### Step 3: Redeploy LiteLLM Proxy

**IMPORTANT:** Must run from `ansible/` directory:

```bash
cd ~/miket-infra-devices/ansible

ansible-playbook -i inventory/hosts.yml \
  playbooks/motoko/deploy-litellm.yml \
  --limit motoko \
  --connection=local
```

This regenerates the LiteLLM config with the correct Wintermute model using the `{{ wintermute_model_display }}` variable.

### Step 4: Verify Configuration

**Check Wintermute vLLM model:**
```bash
# Check config file
ansible wintermute -i inventory/hosts.yml -m win_shell \
  -a "Get-Content C:\ProgramData\WintermuteMode\vllm_config.json | ConvertFrom-Json | Select-Object model" \
  --ask-vault-pass

# Check running container
ansible wintermute -i inventory/hosts.yml -m win_shell \
  -a "docker ps --filter name=vllm-wintermute --format '{{.Names}} {{.Status}}'" \
  --ask-vault-pass
```

**Check LiteLLM models:**
```bash
curl http://motoko.tail2e55fe.ts.net:8000/v1/models \
  -H "Authorization: Bearer YOUR_TOKEN" | jq '.data[] | select(.id | contains("reasoner"))'
```

**Test Wintermute API directly:**
```bash
# Health check
curl http://wintermute.tail2e55fe.ts.net:8000/health

# List models (should show Llama 3.1 8B)
curl http://wintermute.tail2e55fe.ts.net:8000/v1/models | jq '.data[].id'
```

## Expected Results

After deployment:

1. **Wintermute config file** (`C:\ProgramData\WintermuteMode\vllm_config.json`):
   ```json
   {
     "model": "meta-llama/Meta-Llama-3.1-8B-Instruct-AWQ",
     "port": 8000,
     "gpu_memory_utilization": 0.95,
     "max_model_len": 8192
   }
   ```

2. **LiteLLM config** (`/opt/litellm/litellm.config.yaml`):
   ```yaml
   - model_name: local/reasoner
     litellm_params:
       model: openai/llama-3.1-8b-instruct-awq
       api_base: "http://wintermute:8000/v1"
   ```

3. **vLLM container** should be running with Llama 3.1 8B model

4. **LiteLLM** should route `local/reasoner` requests to Wintermute correctly

## Troubleshooting

### If Wintermute deployment fails (WinRM):
- Verify WinRM is configured: `ansible wintermute -i inventory/hosts.yml -m win_ping --ask-vault-pass`
- Check vault password is correct
- Verify Tailscale connectivity

### If LiteLLM deployment fails:
- **Make sure you're in the `ansible/` directory** - group_vars won't load from elsewhere
- Check that `host_vars/motoko.yml` exists and has all required variables
- Verify with: `ansible motoko -i inventory/hosts.yml -m debug -a "var=wintermute_model_display" --connection=local`

### If wrong model is still running:
- Stop container: `.\Start-VLLM.ps1 -Action Stop`
- Remove container: `docker rm vllm-wintermute`
- Start fresh: `.\Start-VLLM.ps1 -Action Start`

## Summary

✅ All configuration files fixed  
✅ Playbooks validated  
✅ Ready for deployment  

**Next:** Run the deployment steps above to apply the fixes.
