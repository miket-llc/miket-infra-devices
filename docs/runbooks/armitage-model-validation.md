# Armitage Model Validation and Deployment

This document describes how to validate that Armitage is running the correct model (Qwen2.5-7B-Instruct) and that the full vLLM → LiteLLM → Ansible control flow works end-to-end.

## Overview

The validation process ensures:
1. Armitage is running Qwen2.5-7B-Instruct (fp16/bf16 build)
2. vLLM is configured with correct parameters
3. LiteLLM proxy on Motoko routes requests correctly
4. End-to-end connectivity and functionality works
5. Ansible integration works without manual intervention

## Quick Validation

From Motoko (Ansible control node):

```bash
cd ~/miket-infra-devices
./scripts/Validate-Armitage-Model.sh
```

This will generate a validation report at `artifacts/armitage-deploy-report.txt`.

## Detailed Validation Steps

### 1. Verify Deployed Model on Armitage

**Check vLLM container status:**
```bash
# From Motoko
ansible armitage -i ansible/inventory/hosts.yml \
  -m win_shell \
  -a "docker ps --filter name=vllm-armitage"
```

**Query model API:**
```bash
curl http://armitage.tail2e55fe.ts.net:8000/v1/models
```

Expected response should show `Qwen/Qwen2.5-7B-Instruct` or `qwen2.5-7b-armitage`.

**Check container launch arguments:**
```bash
ansible armitage -i ansible/inventory/hosts.yml \
  -m win_shell \
  -a "docker inspect vllm-armitage --format '{{.Args}}'"
```

Should include:
- `--model Qwen/Qwen2.5-7B-Instruct`
- `--dtype bf16`
- `--max-model-len 8192`
- `--max-num-seqs 2`
- `--gpu-memory-utilization 0.9`
- `--served-model-name qwen2.5-7b-armitage`

**Check GPU memory usage:**
```bash
ansible armitage -i ansible/inventory/hosts.yml \
  -m win_shell \
  -a "\"C:\Program Files\NVIDIA Corporation\NVSMI\nvidia-smi.exe\" --query-gpu=memory.used,memory.total --format=csv"
```

### 2. Update Model if Mismatch

If the model is incorrect or outdated:

**Option A: Use Ansible playbook (recommended):**
```bash
cd ~/miket-infra-devices
ansible-playbook -i ansible/inventory/hosts.yml \
  ansible/playbooks/armitage-vllm-validate.yml \
  --limit armitage \
  --ask-vault-pass
```

**Option B: Manual update on Armitage:**
```powershell
# On Armitage
cd C:\Users\mdt\dev\armitage\scripts
.\Start-VLLM.ps1 -Action Stop
.\Start-VLLM.ps1 -Action Start
```

The script will automatically use the model from `config.yml`.

### 3. Verify LiteLLM Proxy Configuration

**Check LiteLLM config file:**
```bash
# On Motoko
cat /etc/litellm/config.yaml
# or
cat ~/litellm/config.yaml
```

Should contain:
```yaml
model_list:
  - model_name: qwen2.5-7b-armitage
    litellm_params:
      model: openai/Qwen-Qwen2.5-7B-Instruct
      api_base: http://armitage.tail2e55fe.ts.net:8000/v1
      api_key: dummy
    model_info:
      max_input_tokens: 7000
      max_output_tokens: 768
    tpm: 80000
    rpm: 40
    max_parallel_requests: 2
```

**Update LiteLLM config if needed:**
```bash
# Copy template
sudo cp ~/miket-infra-devices/configs/litellm/config.yaml.template /etc/litellm/config.yaml
# Edit as needed
sudo nano /etc/litellm/config.yaml
# Restart LiteLLM
sudo systemctl restart litellm
# or if using Docker
docker compose -f /path/to/litellm/docker-compose.yml restart
```

**Check LiteLLM service status:**
```bash
sudo systemctl status litellm
# or
docker ps --filter name=litellm
```

### 4. Connectivity and Health Checks

**From Motoko, test connectivity:**
```bash
# Test Ansible connectivity
ansible armitage -i ansible/inventory/hosts.yml -m win_ping

# Test vLLM health endpoint
curl http://armitage.tail2e55fe.ts.net:8000/health

# Test vLLM models endpoint
curl http://armitage.tail2e55fe.ts.net:8000/v1/models

# Test LiteLLM health endpoint
curl http://localhost:4000/health

# Test LiteLLM models endpoint
curl http://localhost:4000/v1/models
```

Expected: All endpoints should respond successfully.

### 5. Functional Tests

**Test direct vLLM API:**
```bash
curl -X POST http://armitage.tail2e55fe.ts.net:8000/v1/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Qwen/Qwen2.5-7B-Instruct",
    "prompt": "Hello, how are you?",
    "max_tokens": 50
  }'
```

**Test LiteLLM proxy:**
```bash
curl -X POST http://localhost:4000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "qwen2.5-7b-armitage",
    "messages": [{"role": "user", "content": "Hello, how are you?"}],
    "max_tokens": 50
  }'
```

**Test Ansible integration:**
```bash
# Create a test playbook that calls the model
ansible-playbook -i ansible/inventory/hosts.yml \
  ansible/playbooks/test-model-integration.yml \
  --limit armitage
```

### 6. Troubleshooting

#### Out of Memory (OOM) Errors

If vLLM container crashes with OOM:
- Lower `max-model-len` to 4096 or 2048
- Set `--kv-cache-dtype fp8` in Start-VLLM.ps1
- Reduce `gpu-memory-utilization` to 0.8 or 0.7
- Reduce `max-num-seqs` to 1

**Update config.yml:**
```yaml
vllm:
  max_model_len: 4096
  max_num_seqs: 1
  gpu_memory_utilization: 0.8
```

#### Connection Errors (404/503)

**Check firewall:**
```powershell
# On Armitage
Get-NetFirewallRule | Where-Object {$_.DisplayName -like "*8000*"}
```

**Check Tailnet connectivity:**
```bash
# From Motoko
ping armitage.tail2e55fe.ts.net
tailscale ping armitage.tail2e55fe.ts.net
```

**Check port conflicts:**
```powershell
# On Armitage
netstat -ano | findstr :8000
```

#### Model Mismatch

If the wrong model is running:
1. Stop the container: `.\Start-VLLM.ps1 -Action Stop`
2. Verify `config.yml` has correct model
3. Start the container: `.\Start-VLLM.ps1 -Action Start`
4. Wait for model to load (can take 2-5 minutes)
5. Verify: `curl http://armitage.tail2e55fe.ts.net:8000/v1/models`

#### LiteLLM Not Routing Correctly

**Check LiteLLM logs:**
```bash
# On Motoko
sudo journalctl -u litellm -f
# or
docker logs litellm
```

**Verify API base URL:**
- Ensure `armitage.tail2e55fe.ts.net` resolves correctly
- Test direct connection: `curl http://armitage.tail2e55fe.ts.net:8000/v1/models`

**Restart LiteLLM:**
```bash
sudo systemctl restart litellm
# or
docker compose restart litellm
```

#### High Latency

If responses are slow:
- Reduce `max-num-seqs` to 1
- Check GPU utilization: `nvidia-smi`
- Check if other processes are using GPU
- Consider using `--disable-log-requests` for better performance

#### Authentication/1Password Prompts

If Ansible prompts for passwords:
- Ensure vault password is set: `export ANSIBLE_VAULT_PASSWORD_FILE=~/.ansible/vault_pass`
- Use `--ask-vault-pass` flag
- Check WinRM configuration on Armitage

### 7. Validation Report

After running the validation script, review the report:

```bash
cat artifacts/armitage-deploy-report.txt
```

The report includes:
- Model checksum/build info
- vLLM startup arguments
- GPU memory usage snapshot
- LiteLLM route status
- Health check results
- Test prompt output and latency
- Warnings and next-step suggestions

## Acceptance Criteria

✅ **Model Verification:**
- `curl http://armitage.tail2e55fe.ts.net:8000/v1/models` returns only Qwen2.5-7B-Instruct
- Container args include `--model Qwen/Qwen2.5-7B-Instruct`
- Container args include `--dtype bf16`
- Container args include `--max-model-len 8192`

✅ **LiteLLM Proxy:**
- LiteLLM exposes `qwen2.5-7b-armitage` model
- Requests to LiteLLM proxy successfully reach vLLM
- Response latency < 2s for short prompts

✅ **Ansible Integration:**
- `ansible armitage -i ansible/inventory/hosts.yml -m win_ping` succeeds
- Playbooks can manage vLLM container
- No manual intervention required

✅ **End-to-End Flow:**
- Direct vLLM API works
- LiteLLM proxy works
- Ansible can control deployment
- No authentication prompts during automation

## Configuration Files

- **Armitage config:** `devices/armitage/config.yml`
- **vLLM script:** `devices/armitage/scripts/Start-VLLM.ps1`
- **LiteLLM config:** `/etc/litellm/config.yaml` (on Motoko)
- **Ansible playbook:** `ansible/playbooks/armitage-vllm-validate.yml`
- **Validation script:** `scripts/Validate-Armitage-Model.sh`

## Related Documentation

- [Armitage vLLM Setup](armitage-vllm.md)
- [Armitage Docker NVIDIA Debug](armitage-docker-nvidia-debug.md)
- [Ansible Windows Setup](ansible-windows-setup.md)

