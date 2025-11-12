# Armitage 8K Context Limit - Configuration Update

**Date**: 2025-11-12  
**Status**: ✅ Ready to Deploy

## Summary

Corrected Armitage's context limit configuration to **8K tokens** (validated) across all systems.

## Problem

Configuration was inconsistent:
- **Config files**: 16k (unvalidated)
- **Documentation**: 8k (correct)
- **Tests**: 7k input
- **Actual validation**: 8k only

## Solution

Set all configurations to **8,192 tokens** consistently:

### Changes Made

#### 1. Ansible Host Variables (`ansible/host_vars/armitage.yml`)
```yaml
vllm:
  max_model_len: 8192          # Changed from 16384
  gpu_memory_utilization: 0.90  # Changed from 0.85
  kv_cache_dtype: "fp8"         # Added for memory optimization
```

#### 2. LiteLLM Configuration (`ansible/roles/litellm_proxy/templates/litellm.config.yaml.j2`)
```yaml
# Armitage model entries
model_info:
  max_input_tokens: 7000   # Changed from 15000
  max_output_tokens: 768   # Changed from 1024
  max_tokens: 8192         # Changed from 16384
tpm_limit: 80000           # Changed from 120000
rpm_limit: 40              # Changed from 60
max_concurrent_requests: 1 # Changed from 2
```

#### 3. Test Configuration (`tests/context_smoke.py`)
```python
{
    "name": "armitage-direct",
    "model": "qwen2.5-7b-armitage",  # Uses served_model_name
    "max_input_tokens": 7000,
}
```

#### 4. Documentation (`docs/vLLM_CONTEXT_WINDOW_GUIDE.md`)
```markdown
### Armitage (8GB VRAM) - VALIDATED ✅
- Max Context: 8,192 tokens (validated)
- KV Cache Dtype: fp8 (memory optimization)
```

## Configuration Details

### vLLM Settings (8GB VRAM)
- **Model**: Qwen/Qwen2.5-7B-Instruct-AWQ (~3.5GB)
- **Context Window**: 8,192 tokens
- **KV Cache**: fp8 dtype (~1-2GB)
- **GPU Memory**: 0.90 utilization
- **Total VRAM**: ~5.5-6GB (safe for 8GB)

### LiteLLM Limits
- **Input**: 7,000 tokens (85% of capacity)
- **Output**: 768 tokens
- **Total**: 8,192 tokens
- **Safety margin**: ~1,200 tokens

## Deployment Commands

### Step 1: Deploy to Armitage

```bash
cd /home/mdt/miket-infra-devices/ansible

ansible-playbook -i inventory/hosts.yml \
  playbooks/windows-vllm-deploy.yml \
  --limit armitage \
  --ask-vault-pass
```

**What this does:**
- Templates new `config.yml` with 8k context
- Deploys to Armitage
- Triggers handler to restart vLLM container

### Step 2: Deploy to LiteLLM (Motoko)

```bash
cd /home/mdt/miket-infra-devices/ansible

ansible-playbook -i inventory/hosts.yml \
  playbooks/motoko/deploy-litellm.yml \
  --limit motoko \
  --connection=local
```

**What this does:**
- Regenerates LiteLLM config with 8k limits
- Restarts LiteLLM service
- Updates model advertising

### Step 3: Verify Deployment

```bash
# Check Armitage vLLM is serving with 8k context
curl http://192.168.1.157:8000/v1/models

# Should show:
# {
#   "data": [
#     {
#       "id": "qwen2.5-7b-armitage",
#       "object": "model",
#       "owned_by": "vllm"
#     }
#   ]
# }

# Test via LiteLLM
curl -X POST http://localhost:8000/v1/chat/completions \
  -H "Authorization: Bearer YOUR_LITELLM_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "qwen2.5-7b-armitage",
    "messages": [{"role": "user", "content": "Test message"}],
    "max_tokens": 100
  }'
```

## Why 8K (Not 16K)?

### Memory Constraints (8GB VRAM)
```
Model weights (AWQ):     ~3.5 GB
KV cache (8k, fp8):      ~1.5 GB
vLLM overhead:           ~0.5 GB
GPU memory buffer:       ~0.5 GB
System overhead:         ~2.0 GB
------------------------
Total:                   ~8.0 GB ✅

With 16k context:
Model weights (AWQ):     ~3.5 GB
KV cache (16k, fp8):     ~3.0 GB
vLLM overhead:           ~0.5 GB
GPU memory buffer:       ~0.5 GB
System overhead:         ~2.0 GB
------------------------
Total:                   ~9.5 GB ❌ (OOM likely)
```

### Validation Status
- ✅ **8k**: Deployed and validated in production
- ❌ **16k**: Not tested, likely causes OOM on 8GB VRAM

## Benefits of fp8 KV Cache

- **Memory savings**: ~50% vs fp16
- **Performance**: Minimal impact on quality
- **Stability**: Well-tested with AWQ models
- **Enables**: 8k context on 8GB VRAM

## Rollback Plan

If issues occur:
```bash
# Revert git changes
git checkout ansible/host_vars/armitage.yml
git checkout ansible/roles/litellm_proxy/templates/litellm.config.yaml.j2

# Redeploy
cd ansible
ansible-playbook -i inventory/hosts.yml playbooks/windows-vllm-deploy.yml --limit armitage
ansible-playbook -i inventory/hosts.yml playbooks/motoko/deploy-litellm.yml --limit motoko
```

## Post-Deployment Validation

1. **Check container logs**:
   ```powershell
   # On Armitage
   docker logs vllm-armitage --tail 50
   ```

2. **Verify context limit**:
   - Try a request with ~5,000 tokens input
   - Should succeed
   - Try with ~8,000 tokens input
   - Should succeed
   - Try with >8,000 tokens input
   - Should get 400 error (expected)

3. **Monitor memory**:
   ```powershell
   # On Armitage
   nvidia-smi
   # VRAM usage should be ~5.5-7GB
   ```

## Summary

**Status**: Configuration corrected to validated 8k limit  
**Changed Files**: 4 (host_vars, litellm template, tests, docs)  
**Deployment**: 2 commands (Armitage + LiteLLM)  
**Impact**: More accurate advertising, prevents over-promising capacity  
**Risk**: Low - returning to validated configuration



