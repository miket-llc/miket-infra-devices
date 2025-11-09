# vLLM Context Window & Throttling Configuration Guide

## Overview

This guide documents the vLLM and LiteLLM configuration updates for increased context windows, throttling, and deployment procedures for Wintermute and Armitage.

## Configuration Summary

### Wintermute (12GB VRAM)
- **Model**: Llama-3.1-8B-Instruct (AWQ)
- **Max Context**: 16,384 tokens
- **Max Concurrent Sequences**: 2
- **GPU Memory Utilization**: 0.92
- **KV Cache Dtype**: fp8 (fallback to fp16 if unstable)
- **LiteLLM Limits**:
  - max_input_tokens: 14,000
  - max_output_tokens: 1,024
  - TPM: 120,000
  - RPM: 60
  - Concurrency: 2

### Armitage (8GB VRAM)
- **Model**: Qwen2.5-7B-Instruct (AWQ)
- **Max Context**: 8,192 tokens
- **Max Concurrent Sequences**: 1
- **GPU Memory Utilization**: 0.90
- **KV Cache Dtype**: fp8 (fallback to fp16 if unstable)
- **LiteLLM Limits**:
  - max_input_tokens: 7,000
  - max_output_tokens: 768
  - TPM: 80,000
  - RPM: 40
  - Concurrency: 1

## Deployment

### Prerequisites

1. Ensure Docker Desktop is running
2. Verify GPU access: `nvidia-smi` (Windows) or `docker run --rm --gpus all nvidia/cuda:12.0.0-base-ubuntu22.04 nvidia-smi`
3. Backup current configurations: `make backup-configs`

### Deploy Wintermute

```bash
# From repository root
make deploy-wintermute

# Or manually:
cd devices/wintermute/scripts
./Start-VLLM.ps1 Restart

# Or via WSL2:
bash vllm.sh restart
```

### Deploy Armitage

```bash
# From repository root
make deploy-armitage

# Or manually:
cd devices/armitage/scripts
./Start-VLLM.ps1 Restart
```

### Deploy LiteLLM Proxy

```bash
# From repository root (requires Ansible)
make deploy-proxy

# Or manually on Motoko:
sudo systemctl restart litellm
sudo journalctl -u litellm -f
```

## Testing

### Context Window Smoke Test

Tests that models can handle requests near their max context limits:

```bash
make test-context
# Or directly:
python3 tests/context_smoke.py
```

This will:
- Send requests with ~75% of max_input_tokens to each model
- Measure latency (P50, P90)
- Verify no OOM errors
- Generate report: `artifacts/context_test_results.csv`

### Burst Load Test

Tests concurrent request handling and queueing:

```bash
make test-burst
# Or directly:
python3 tests/burst_test.py
```

This will:
- Send 5 concurrent requests to Wintermute
- Verify queueing behavior (not OOM)
- Check for 429 rate limit responses
- Generate report: `artifacts/burst_test_results.csv`

### Health Checks

```bash
# Check all services
make health-check

# Individual checks
make health-check-wintermute
make health-check-armitage
make health-check-proxy
```

## Troubleshooting

### OOM at Startup

**Symptoms**: Container crashes immediately after start, GPU memory errors in logs

**Solutions**:
1. Reduce `--max-model-len`:
   - Wintermute: 16384 → 12288 → 8192
   - Armitage: 8192 → 6144 → 4096
2. Reduce `--gpu-memory-utilization`:
   - Wintermute: 0.92 → 0.85 → 0.80
   - Armitage: 0.90 → 0.85 → 0.80
3. Switch KV cache dtype to fp16:
   - Edit `config.yml`: `kv_cache_dtype: "fp16"`
   - Restart container

**Quick rollback**:
```bash
# Edit config.yml to reduce max_model_len by 25%
# Then restart
cd devices/wintermute/scripts && ./Start-VLLM.ps1 Restart
```

### Random Crashes / Instability

**Symptoms**: Container runs but crashes intermittently, CUDA errors

**Solutions**:
1. Disable fp8 KV cache (use fp16):
   ```yaml
   # In config.yml
   kv_cache_dtype: "fp16"
   ```
2. Reduce `--max-num-seqs`:
   - Wintermute: 2 → 1
   - Armitage: 1 (already minimum)
3. Check GPU driver version:
   ```bash
   nvidia-smi
   # Ensure CUDA 12.x compatible driver
   ```

### Latency Spikes

**Symptoms**: P90 latency > 30s, requests timing out

**Solutions**:
1. Reduce `--max-num-seqs`:
   - Lower concurrent sequences = lower latency per request
2. Reduce LiteLLM `tpm` limit:
   - Edit `ansible/roles/litellm_proxy/templates/litellm.config.yaml.j2`
   - Reduce `tpm_limit` by 20-30%
   - Redeploy: `make deploy-proxy`
3. Reduce `max_input_tokens` in LiteLLM config:
   - Prevents oversized requests from blocking queue

### Token Limit Errors (4xx)

**Symptoms**: "Request exceeds max_input_tokens" errors

**Solutions**:
1. Verify LiteLLM `max_input_tokens` aligns with vLLM `--max-model-len`:
   - LiteLLM should be ~85-90% of vLLM max
   - Example: vLLM 16384 → LiteLLM 14000
2. Check request token count:
   ```python
   # Estimate tokens: ~4 chars per token
   token_count = len(prompt) // 4
   ```
3. Use burst profile for large jobs:
   - Model: `llama31-8b-wintermute-burst`
   - Allows up to 15,000 input tokens

### Rate Limiting (429 Errors)

**Symptoms**: Frequent 429 responses, "Retry-After" headers

**Solutions**:
1. This is **expected behavior** - throttling is working
2. For burst workloads, use burst profile:
   ```python
   model = "llama31-8b-wintermute-burst"  # Higher limits
   ```
3. Implement exponential backoff in client:
   ```python
   import time
   retry_after = int(response.headers.get("Retry-After", 60))
   time.sleep(retry_after)
   ```

### Windows-Specific Issues (Armitage/Wintermute)

**Symptoms**: Container won't start, GPU not detected

**Solutions**:
1. Verify Docker Desktop GPU support:
   ```powershell
   docker run --rm --gpus all nvidia/cuda:12.0.0-base-ubuntu22.04 nvidia-smi
   ```
2. Check WSL2 NVIDIA driver:
   ```powershell
   wsl -d Ubuntu -- nvidia-smi
   ```
3. Restart Docker Desktop:
   - Right-click Docker Desktop tray icon → Restart
4. Verify NVIDIA Container Toolkit in WSL2:
   ```powershell
   wsl -d Ubuntu -- dpkg -l | grep nvidia-container-toolkit
   ```

### LiteLLM Proxy Issues

**Symptoms**: Proxy returns 5xx errors, routes not working

**Solutions**:
1. Check proxy logs:
   ```bash
   sudo journalctl -u litellm -f
   ```
2. Verify backend connectivity:
   ```bash
   curl http://wintermute.tailnet.local:8000/v1/models
   curl http://armitage.tailnet.local:8000/v1/models
   ```
3. Check configuration syntax:
   ```bash
   # On Motoko
   litellm --config /opt/litellm/litellm.config.yaml --test
   ```
4. Restart proxy:
   ```bash
   sudo systemctl restart litellm
   ```

## Rollback Procedures

### Rollback Wintermute

```bash
# List available backups
ls -1t backups/ | head -5

# Restore from backup
make rollback-wintermute
# Follow prompts to select backup timestamp

# Or manually:
cp backups/YYYYMMDD_HHMMSS/wintermute_config.yml devices/wintermute/config.yml
cp backups/YYYYMMDD_HHMMSS/wintermute_Start-VLLM.ps1 devices/wintermute/scripts/Start-VLLM.ps1
cd devices/wintermute/scripts && ./Start-VLLM.ps1 Restart
```

### Rollback Armitage

```bash
make rollback-armitage
# Follow prompts

# Or manually restore from backups/ directory
```

### Rollback LiteLLM Proxy

```bash
make rollback-proxy
# Then redeploy:
make deploy-proxy
```

### Emergency Quick Rollback (Reduce Context)

If experiencing OOM and need immediate fix:

```bash
# Wintermute: Reduce to 8k context
sed -i 's/max_model_len: 16384/max_model_len: 8192/' devices/wintermute/config.yml
cd devices/wintermute/scripts && ./Start-VLLM.ps1 Restart

# Armitage: Reduce to 4k context
sed -i 's/max_model_len: 8192/max_model_len: 4096/' devices/armitage/config.yml
cd devices/armitage/scripts && ./Start-VLLM.ps1 Restart
```

## Monitoring

### Check vLLM Status

```bash
# Wintermute
docker logs vllm-wintermute --tail 50

# Armitage
docker logs vllm-armitage --tail 50
```

### Check GPU Memory Usage

```bash
# Windows
nvidia-smi

# WSL2
wsl -d Ubuntu -- nvidia-smi
```

### Check LiteLLM Metrics

```bash
# On Motoko
curl http://localhost:8000/metrics
```

## Model Aliases

### Standard Models
- `local/chat` → Armitage (Qwen2.5-7B)
- `local/reasoner` → Wintermute (Llama-3.1-8B)
- `qwen2.5-7b-armitage` → Explicit Armitage alias
- `llama31-8b-wintermute` → Explicit Wintermute alias

### Burst Profile
- `llama31-8b-wintermute-burst` → Higher limits for heavy workloads
  - max_input_tokens: 15,000 (vs 14,000 standard)
  - TPM: 140,000 (vs 120,000 standard)
  - Use for batch jobs or large document processing

## Configuration Files

### vLLM Configuration
- **Wintermute**: `devices/wintermute/config.yml`
- **Armitage**: `devices/armitage/config.yml`
- **Scripts**: `devices/{wintermute,armitage}/scripts/Start-VLLM.ps1`

### LiteLLM Configuration
- **Template**: `ansible/roles/litellm_proxy/templates/litellm.config.yaml.j2`
- **Deployed**: `/opt/litellm/litellm.config.yaml` (on Motoko)

## Best Practices

1. **Always backup before changes**: `make backup-configs`
2. **Test incrementally**: Start with conservative limits, increase gradually
3. **Monitor during deployment**: Watch logs and GPU memory
4. **Use burst profile sparingly**: Only for known heavy workloads
5. **Implement client-side retries**: Handle 429 responses gracefully
6. **Set timeouts**: Client timeouts should be < LiteLLM timeout (300s)

## Support

For issues or questions:
1. Check logs: `docker logs <container-name>`
2. Review this troubleshooting guide
3. Check GitHub issues: https://github.com/miket-llc/miket-infra-devices/issues

## Changelog

### 2025-01-XX - Context Window Update
- Increased Wintermute context: 8k → 16k
- Increased Armitage context: 4k → 8k
- Added fp8 KV cache support
- Added LiteLLM throttling and rate limits
- Added burst profile for Wintermute
- Added comprehensive test suite
- Added rollback procedures

