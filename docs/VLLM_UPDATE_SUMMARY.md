# vLLM Context Window Update - Implementation Summary

**Date**: 2025-01-XX  
**Status**: ✅ Ready for Deployment

## Changes Summary

### Configuration Updates

#### Wintermute (12GB VRAM)
- ✅ Increased context window: **8k → 16k tokens**
- ✅ Added `max-num-seqs=2` for concurrent processing
- ✅ Added `kv-cache-dtype=fp8` for memory efficiency
- ✅ Updated GPU memory utilization: **0.90 → 0.92**
- ✅ Updated LiteLLM limits:
  - max_input_tokens: 14,000
  - max_output_tokens: 1,024
  - TPM: 120,000
  - RPM: 60
  - Concurrency: 2

#### Armitage (8GB VRAM)
- ✅ Increased context window: **4k → 8k tokens**
- ✅ Added `max-num-seqs=1` for single-sequence processing
- ✅ Added `kv-cache-dtype=fp8` for memory efficiency
- ✅ Updated GPU memory utilization: **0.85 → 0.90**
- ✅ Updated LiteLLM limits:
  - max_input_tokens: 7,000
  - max_output_tokens: 768
  - TPM: 80,000
  - RPM: 40
  - Concurrency: 1

#### LiteLLM Proxy
- ✅ Added per-model throttling (TPM/RPM/concurrency)
- ✅ Added explicit model aliases:
  - `llama31-8b-wintermute`
  - `qwen2.5-7b-armitage`
- ✅ Added burst profile: `llama31-8b-wintermute-burst`
- ✅ Configured request queueing and retries

### Files Modified

1. **devices/wintermute/config.yml** - Updated vLLM parameters
2. **devices/wintermute/scripts/Start-VLLM.ps1** - Added new Docker flags
3. **devices/wintermute/scripts/vllm.sh** - Added new Docker flags
4. **devices/armitage/config.yml** - Updated vLLM parameters
5. **devices/armitage/scripts/Start-VLLM.ps1** - Added new Docker flags
6. **ansible/roles/litellm_proxy/templates/litellm.config.yaml.j2** - Added throttling and model configs

### Files Created

1. **Makefile** - Deployment automation with deploy/rollback targets
2. **tests/context_smoke.py** - Context window validation tests
3. **tests/burst_test.py** - Concurrent load testing
4. **scripts/validate-vllm-config.sh** - Configuration validation script
5. **docs/vLLM_CONTEXT_WINDOW_GUIDE.md** - Comprehensive troubleshooting guide
6. **docs/DEPLOYMENT_CHECKLIST.md** - Step-by-step deployment guide

## Validation Results

✅ All configuration files validated successfully:
- Wintermute config: ✓
- Armitage config: ✓
- PowerShell scripts: ✓
- Bash scripts: ✓
- LiteLLM template: ✓
- Test scripts: ✓

## Next Steps

### 1. Review Changes
```bash
git diff
```

### 2. Backup Current Configurations
```bash
make backup-configs
```

### 3. Deploy to Devices

**Wintermute:**
```bash
make deploy-wintermute
# Or manually: cd devices/wintermute/scripts && ./Start-VLLM.ps1 Restart
```

**Armitage:**
```bash
make deploy-armitage
# Or manually: cd devices/armitage/scripts && ./Start-VLLM.ps1 Restart
```

**LiteLLM Proxy:**
```bash
make deploy-proxy
# Or manually on Motoko: sudo systemctl restart litellm
```

### 4. Verify Health
```bash
make health-check
```

### 5. Run Tests
```bash
make test-context
make test-burst
```

## Acceptance Criteria

- [ ] `num_ctx` effective at 16k (Wintermute) and 8k (Armitage) without OOM
- [ ] Queueing/backpressure works; burst test completes with ≤1 error
- [ ] Proxy rejects over-limit requests with clear 4xx, not 5xx
- [ ] Rollback restores previous behavior cleanly

## Rollback Plan

If issues occur:
```bash
make rollback-wintermute
make rollback-armitage
make rollback-proxy
```

Backups are stored in `backups/` directory with timestamps.

## Documentation

- **Troubleshooting**: `docs/vLLM_CONTEXT_WINDOW_GUIDE.md`
- **Deployment**: `docs/DEPLOYMENT_CHECKLIST.md`
- **Makefile Help**: `make help`

## Notes

- fp8 KV cache may cause instability on some systems - fallback to fp16 if needed
- Monitor GPU memory usage closely during first 24 hours
- Burst profile (`llama31-8b-wintermute-burst`) available for heavy workloads
- All changes are backward compatible with rollback capability

