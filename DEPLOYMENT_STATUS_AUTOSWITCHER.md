# Autoswitcher & Model Configuration Deployment Status

**Date**: November 10, 2025  
**Status**: PARTIAL DEPLOYMENT - Wintermute Complete, Armitage Offline

## Summary

Successfully deployed improved autoswitching functionality and correct model configurations to **Wintermute**. **Armitage** is offline (laptop not connected) and pending deployment.

## Deployment Status

### ✅ Wintermute (wintermute.tail2e55fe.ts.net) - DEPLOYED

**Model**: Llama-3.1-8B-Instruct-AWQ (`casperhansen/llama-3-8b-instruct-awq`)  
**Context**: 8192 tokens (native max for this model)  
**Quantization**: AWQ (4-bit)  
**GPU Memory**: 0.85 utilization  
**Status**: Running and operational

**Deployed Components**:
- ✅ Updated `config.yml` with Llama-3.1-8B-AWQ configuration
- ✅ Enhanced `Start-VLLM.ps1` with better config parsing and quantization support
- ✅ Improved `Auto-ModeSwitcher.ps1` with lazy GPU checking to avoid wake-ups
- ✅ Improved `Set-WorkstationMode.ps1` (already had Development mode)
- ✅ Container running with correct model and settings

**Autoswitching Improvements**:
- Uses Windows API for accurate idle time detection (keyboard/mouse activity)
- Expanded list of workstation/GPU-intensive apps for better detection
- Lazy GPU checking - only queries nvidia-smi when necessary
- Checks user activity first (lightweight) before GPU status

### ⏳ Armitage (armitage.tail2e55fe.ts.net) - PENDING (OFFLINE)

**Model**: Qwen2.5-7B-Instruct (`Qwen/Qwen2.5-7B-Instruct`)  
**Context**: 32768 tokens (native max 32k, configured for low concurrency)  
**Data Type**: bf16  
**GPU Memory**: 0.85 utilization  
**Max Sequences**: 1 (optimized for single-user, low concurrency)  
**Status**: Device offline, ready to deploy

**Ready to Deploy**:
- ✅ Updated `devices/armitage/config.yml` with Qwen2.5-7B and 32k context
- ✅ Updated `devices/armitage/scripts/Start-VLLM.ps1` (same improvements as wintermute)
- ✅ Enhanced `Auto-ModeSwitcher.ps1` with same improvements
- ⏳ Waiting for device to come online

## Configuration Changes

### Model Updates

| Device | Old Model | New Model | Context | Quantization |
|--------|-----------|-----------|---------|--------------|
| Wintermute | Mistral-7B-Instruct-v0.2 | Llama-3.1-8B-Instruct-AWQ | 8192 | AWQ (4-bit) |
| Armitage | Qwen2.5-7B-Instruct | Qwen2.5-7B-Instruct | 32768 ↑ | bf16 |

### AutoSwitcher Improvements

**Before**:
- Simple uptime-based idle detection
- Always checked GPU via nvidia-smi (causes GPU wake-up)
- Limited app detection

**After**:
- Windows API-based keyboard/mouse idle detection
- Expanded workstation app list (browsers, IDEs, games, streaming software)
- Lazy GPU checking - only when needed
- Process-based GPU-intensive app detection (no GPU wake needed)

### Scripts Updated

1. **`Start-VLLM.ps1`**:
   - Improved YAML config parsing
   - Support for quantization parameter
   - Support for gpu_memory_utilization from config
   - Support for max_model_len from config
   - Fixed docker command structure for vLLM 0.11.0+

2. **`Auto-ModeSwitcher.ps1`**:
   - Added `Get-IdleTime()` function using Windows API
   - Expanded workstation apps list
   - Added GPU-intensive apps list
   - Lazy GPU checking logic
   - Better logging

3. **`config.yml`** (both devices):
   - Updated model names
   - Added max_model_len
   - Added gpu_memory_utilization
   - Added quantization (wintermute only)

## Deployment Commands

### When Armitage Comes Online

```bash
cd /home/mdt/miket-infra-devices/ansible

# Test connectivity
ansible -i inventory/hosts.yml armitage -m win_ping

# Deploy configuration and scripts
ansible -i inventory/hosts.yml armitage -m win_copy \
  -a "src=../devices/armitage/config.yml dest=C:\\Users\\mdt\\dev\\armitage\\config.yml"

ansible -i inventory/hosts.yml armitage -m win_copy \
  -a "src=../devices/armitage/scripts/Start-VLLM.ps1 dest=C:\\Users\\mdt\\dev\\armitage\\scripts\\Start-VLLM.ps1"

ansible -i inventory/hosts.yml armitage -m win_copy \
  -a "src=../devices/armitage/scripts/Auto-ModeSwitcher.ps1 dest=C:\\Users\\mdt\\dev\\armitage\\scripts\\Auto-ModeSwitcher.ps1"

# Restart vLLM with new configuration
ansible -i inventory/hosts.yml armitage -m win_shell \
  -a "docker rm -f vllm-armitage; powershell -ExecutionPolicy Bypass -File C:\Users\mdt\dev\armitage\scripts\Start-VLLM.ps1 -Action Start"

# Wait 2-3 minutes for model to load, then test
curl http://armitage.tail2e55fe.ts.net:8000/v1/models
```

### Or use the full playbook:
```bash
cd /home/mdt/miket-infra-devices/ansible
ansible-playbook -i inventory/hosts.yml playbooks/remote/armitage-vllm-setup.yml
```

## Troubleshooting

### Wintermute Issues Encountered and Resolved

1. **Issue**: Container kept restarting with V1 engine error
   - **Cause**: Tried to disable V1 engine with `VLLM_USE_V1=0` but vLLM 0.11.0 requires it
   - **Fix**: Removed the environment variable

2. **Issue**: GPU memory error - needed 10.79GB but only 10.76GB free
   - **Cause**: GPU memory utilization set too high (0.90)
   - **Fix**: Reduced to 0.85

3. **Issue**: Context length validation error - requested 16384 but max is 8192
   - **Cause**: Llama-3.1-8B-AWQ has native max of 8192 tokens
   - **Fix**: Set max_model_len to 8192

4. **Issue**: Docker command had duplicate entrypoint
   - **Cause**: Script was adding "python -m vllm.entrypoints.openai.api_server" when image already has it
   - **Fix**: Removed duplicate, just pass model args

## LiteLLM Proxy Status

**Status**: Running but unhealthy (waiting for armitage)

The LiteLLM proxy on motoko is running but shows unhealthy status because it cannot connect to armitage (offline). Once armitage is deployed, the proxy should become healthy automatically.

**Configuration**: Already updated in `ansible/roles/litellm_proxy/templates/litellm.config.yaml.j2` but not yet deployed to reflect:
- Armitage: 32k context limit (up from 8k)
- Wintermute: 8k context (correct for AWQ model)

**To update LiteLLM config** (after armitage is online):
```bash
cd /home/mdt/miket-infra-devices/ansible
ansible-playbook -i inventory/hosts.yml playbooks/deploy-litellm-config.yml
```

## Testing

### Wintermute Tests

```bash
# Health check
curl http://wintermute.tail2e55fe.ts.net:8000/health

# List models
curl http://wintermute.tail2e55fe.ts.net:8000/v1/models

# Simple completion test
curl http://wintermute.tail2e55fe.ts.net:8000/v1/completions \
  -H "Content-Type: application/json" \
  -d '{"model": "casperhansen/llama-3-8b-instruct-awq", "prompt": "Hello", "max_tokens": 50}'
```

### Armitage Tests (when online)

```bash
# Health check
curl http://armitage.tail2e55fe.ts.net:8000/health

# List models
curl http://armitage.tail2e55fe.ts.net:8000/v1/models

# Simple completion test
curl http://armitage.tail2e55fe.ts.net:8000/v1/completions \
  -H "Content-Type: application/json" \
  -d '{"model": "Qwen/Qwen2.5-7B-Instruct", "prompt": "Hello", "max_tokens": 50}'
```

### End-to-End LiteLLM Tests

```bash
# Via proxy (after armitage is online and LiteLLM config updated)
curl http://motoko.tail2e55fe.ts.net:8000/v1/models

# Test wintermute via proxy
curl http://motoko.tail2e55fe.ts.net:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model": "local/reasoner", "messages": [{"role": "user", "content": "Test"}]}'

# Test armitage via proxy  
curl http://motoko.tail2e55fe.ts.net:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model": "local/chat", "messages": [{"role": "user", "content": "Test"}]}'
```

## Next Steps

1. ⏳ **Wait for Armitage to come online**
2. 📋 Deploy config and scripts to Armitage (commands above)
3. ✅ Verify Armitage vLLM is running correctly
4. 🔄 Update and restart LiteLLM proxy with new context limits
5. 🧪 Run end-to-end tests through LiteLLM proxy
6. 📝 Update scheduled task configurations if needed
7. 🎯 Test autoswitching functionality on both devices

## Files Modified

### Configuration
- `devices/wintermute/config.yml` - Updated model, context, quantization
- `devices/armitage/config.yml` - Updated context to 32k, gpu util to 0.85

### Scripts
- `devices/wintermute/scripts/Start-VLLM.ps1` - Enhanced config parsing, quantization support
- `devices/wintermute/scripts/Auto-ModeSwitcher.ps1` - Improved idle detection, lazy GPU checking
- `devices/armitage/scripts/Start-VLLM.ps1` - Same enhancements as wintermute
- `devices/armitage/scripts/Auto-ModeSwitcher.ps1` - Same improvements

### Ansible
- `ansible/playbooks/remote/wintermute-vllm-deploy-scripts.yml` - Fixed vault password loading

## Notes

- **Wintermute AWQ Performance**: The AWQ quantized model uses less GPU memory and is faster than bf16
- **Armitage Context**: 32k context is appropriate for single-user, low-concurrency workload
- **GPU Memory**: Both set to 0.85 to leave headroom for WSL2 overhead and other processes
- **Autoswitching**: Scheduled task runs every 5 minutes, checks are lightweight now

## Success Criteria

- [x] Wintermute running Llama-3.1-8B-AWQ with 8k context
- [ ] Armitage running Qwen2.5-7B with 32k context (pending device online)
- [x] Improved autoswitching deployed to Wintermute  
- [ ] Improved autoswitching deployed to Armitage (pending)
- [ ] LiteLLM proxy healthy and routing correctly (pending armitage)
- [ ] End-to-end tests passing (pending armitage)

