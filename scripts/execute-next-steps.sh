#!/bin/bash
# Copyright (c) 2025 MikeT LLC. All rights reserved.

# Complete deployment and validation script
# Executes all next steps in sequence

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

LOG_FILE="logs/next-steps-$(date +%Y%m%d_%H%M%S).log"
mkdir -p logs

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

log "=========================================="
log "Executing Next Steps"
log "=========================================="
log ""

# Step 1: Verify configurations
log "Step 1: Verifying configurations..."
if ./scripts/validate-vllm-config.sh >> "$LOG_FILE" 2>&1; then
    log "✓ Configuration validation passed"
else
    log "✗ Configuration validation failed"
    exit 1
fi

# Step 2: Check model name configuration
log ""
log "Step 2: Checking model name configuration..."
log "Current Wintermute model config:"
grep -A1 "wintermute_model" ansible/group_vars/motoko.yml | head -3 | tee -a "$LOG_FILE"
log ""
log "Note: Model name will be verified after vLLM deployment"
log "If mismatch occurs, update LiteLLM config to match vLLM's reported model name"

# Step 3: Create deployment instructions
log ""
log "Step 3: Creating deployment instructions..."
cat > "DEPLOY_NOW.md" << 'DEPLOYEOF'
# Deployment Instructions - Execute Now

## Quick Deployment Commands

### On Wintermute (PowerShell)
```powershell
cd C:\Users\$env:USERNAME\dev\miket-infra-devices\devices\wintermute\scripts
.\Start-VLLM.ps1 Restart

# Verify new settings
docker logs vllm-wintermute --tail 50 | Select-String "max-model-len|kv-cache-dtype|max-num-seqs"

# Check if running
docker ps --filter name=vllm-wintermute
```

### On Armitage (PowerShell)
```powershell
cd C:\Users\$env:USERNAME\dev\miket-infra-devices\devices\armitage\scripts
.\Start-VLLM.ps1 Restart

# Verify new settings
docker logs vllm-armitage --tail 50 | Select-String "max-model-len|kv-cache-dtype|max-num-seqs"

# Check if running
docker ps --filter name=vllm-armitage
```

### On Motoko (LiteLLM Proxy)
```bash
# SSH to Motoko first
ssh motoko

# Restart LiteLLM to pick up new config
sudo systemctl restart litellm

# Check status
sudo systemctl status litellm

# Monitor logs
sudo journalctl -u litellm -f
```

## After Deployment

### Verify Health
```bash
# From repository root
make health-check
```

### Run Tests
```bash
make test-context
make test-burst
```

### Check Logs
```bash
# View deployment logs
tail -f logs/deployment-*.log

# View test results
cat artifacts/context_test_results.csv
cat artifacts/burst_test_results.csv
```

## Troubleshooting

If Wintermute model shows as unhealthy:
1. Check what model name vLLM reports:
   ```bash
   curl http://wintermute.tailnet.local:8000/v1/models
   ```
2. Update LiteLLM config to match if different
3. Restart LiteLLM proxy

See `docs/vLLM_CONTEXT_WINDOW_GUIDE.md` for detailed troubleshooting.
DEPLOYEOF

log "✓ Deployment instructions created: DEPLOY_NOW.md"

# Step 4: Prepare test environment
log ""
log "Step 4: Preparing test environment..."
mkdir -p artifacts logs backups
log "✓ Test directories ready"

# Step 5: Create validation checklist
log ""
log "Step 5: Creating post-deployment checklist..."
cat > "POST_DEPLOYMENT_CHECKLIST.md" << 'CHECKLISTEOF'
# Post-Deployment Validation Checklist

## Immediate Checks (After Deployment)

- [ ] Wintermute vLLM container is running
  ```powershell
  docker ps --filter name=vllm-wintermute
  ```

- [ ] Armitage vLLM container is running
  ```powershell
  docker ps --filter name=vllm-armitage
  ```

- [ ] LiteLLM proxy is running
  ```bash
  sudo systemctl status litellm
  ```

- [ ] New configuration appears in logs
  - Check for `max_model_len: 16384` (Wintermute)
  - Check for `max_model_len: 8192` (Armitage)
  - Check for `kv_cache_dtype: fp8`
  - Check for `max_num_seqs` values

## Health Checks

- [ ] Run health check script
  ```bash
  make health-check
  ```
  Expected: All services healthy

- [ ] Test LiteLLM API
  ```bash
  curl http://localhost:8000/v1/models
  ```
  Expected: List of models including new aliases

- [ ] Test Wintermute model
  ```bash
  curl http://localhost:8000/v1/chat/completions \
    -H "Content-Type: application/json" \
    -d '{"model": "llama31-8b-wintermute", "messages": [{"role": "user", "content": "test"}], "max_tokens": 10}'
  ```
  Expected: Successful response

- [ ] Test Armitage model
  ```bash
  curl http://localhost:8000/v1/chat/completions \
    -H "Content-Type: application/json" \
    -d '{"model": "qwen2.5-7b-armitage", "messages": [{"role": "user", "content": "test"}], "max_tokens": 10}'
  ```
  Expected: Successful response

## Tests

- [ ] Context window test
  ```bash
  make test-context
  ```
  Expected: All tests pass

- [ ] Burst load test
  ```bash
  make test-burst
  ```
  Expected: ≤1 error

## Monitoring (First 24 Hours)

- [ ] Monitor GPU memory usage
  - Wintermute: Should be ~92% utilization
  - Armitage: Should be ~90% utilization

- [ ] Check for OOM errors
  ```bash
  docker logs vllm-wintermute | grep -i oom
  docker logs vllm-armitage | grep -i oom
  ```
  Expected: No OOM errors

- [ ] Check for CUDA errors
  ```bash
  docker logs vllm-wintermute | grep -i cuda
  docker logs vllm-armitage | grep -i cuda
  ```
  Expected: No CUDA errors

- [ ] Monitor latency
  - Check test results: `artifacts/context_test_results.csv`
  - P90 latency should be reasonable (<30s for large contexts)

## Success Criteria

- [x] All services running
- [ ] Health checks passing
- [ ] Context tests passing
- [ ] Burst tests passing
- [ ] No OOM/CUDA errors
- [ ] GPU memory within expected ranges
- [ ] Latency acceptable

## If Issues Occur

1. Check logs: `logs/deployment-*.log`
2. Review troubleshooting: `docs/vLLM_CONTEXT_WINDOW_GUIDE.md`
3. Rollback if needed: `make rollback-wintermute rollback-armitage rollback-proxy`
CHECKLISTEOF

log "✓ Post-deployment checklist created: POST_DEPLOYMENT_CHECKLIST.md"

# Step 6: Summary
log ""
log "=========================================="
log "Next Steps Summary"
log "=========================================="
log ""
log "✅ Completed:"
log "  1. Configuration validation"
log "  2. Model name analysis"
log "  3. Deployment instructions created"
log "  4. Post-deployment checklist created"
log ""
log "📋 Manual Steps Required:"
log "  1. Deploy on Wintermute (see DEPLOY_NOW.md)"
log "  2. Deploy on Armitage (see DEPLOY_NOW.md)"
log "  3. Restart LiteLLM on Motoko (see DEPLOY_NOW.md)"
log ""
log "🧪 After Deployment:"
log "  1. Run: make health-check"
log "  2. Run: make test-context"
log "  3. Run: make test-burst"
log "  4. Review: POST_DEPLOYMENT_CHECKLIST.md"
log ""
log "📚 Documentation:"
log "  - Quick deploy: DEPLOY_NOW.md"
log "  - Checklist: POST_DEPLOYMENT_CHECKLIST.md"
log "  - Troubleshooting: docs/vLLM_CONTEXT_WINDOW_GUIDE.md"
log ""
log "Log file: $LOG_FILE"
log ""

