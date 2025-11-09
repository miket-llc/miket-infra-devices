# vLLM Context Window Update - Deployment Checklist

## Pre-Deployment Checklist

- [ ] **Backup current configurations**
  ```bash
  make backup-configs
  ```

- [ ] **Verify connectivity to devices**
  ```bash
  ping wintermute.tailnet.local
  ping armitage.tailnet.local
  ping motoko.tailnet.local
  ```

- [ ] **Check current vLLM status**
  - Wintermute: `docker ps | grep vllm-wintermute`
  - Armitage: `docker ps | grep vllm-armitage`

- [ ] **Verify GPU availability**
  - On Wintermute/Armitage: `nvidia-smi`
  - Check Docker GPU access: `docker run --rm --gpus all nvidia/cuda:12.0.0-base-ubuntu22.04 nvidia-smi`

## Deployment Steps

### Step 1: Backup Configurations
```bash
make backup-configs
```
This creates timestamped backups in `backups/` directory.

### Step 2: Deploy Wintermute
**Option A: Using Makefile (requires SSH access)**
```bash
make deploy-wintermute
```

**Option B: Manual deployment**
1. SSH/RDP to Wintermute
2. Navigate to scripts directory:
   ```powershell
   cd C:\Users\$env:USERNAME\dev\wintermute\scripts
   # Or if using WSL2:
   cd ~/dev/wintermute/scripts
   ```
3. Restart vLLM:
   ```powershell
   # PowerShell
   .\Start-VLLM.ps1 Restart
   
   # Or WSL2 bash
   bash vllm.sh restart
   ```
4. Verify startup:
   ```powershell
   docker logs vllm-wintermute --tail 50
   ```
5. Check for OOM errors or CUDA issues in logs

### Step 3: Deploy Armitage
**Option A: Using Makefile**
```bash
make deploy-armitage
```

**Option B: Manual deployment**
1. SSH/RDP to Armitage
2. Navigate to scripts:
   ```powershell
   cd C:\Users\$env:USERNAME\dev\armitage\scripts
   ```
3. Restart vLLM:
   ```powershell
   .\Start-VLLM.ps1 Restart
   ```
4. Verify startup:
   ```powershell
   docker logs vllm-armitage --tail 50
   ```

### Step 4: Deploy LiteLLM Proxy
**Option A: Using Ansible (recommended)**
```bash
make deploy-proxy
```

**Option B: Manual deployment on Motoko**
```bash
ssh motoko
sudo systemctl restart litellm
sudo journalctl -u litellm -f
```

### Step 5: Verify Health
```bash
make health-check
```

Expected output:
```
✅ Wintermute vLLM is healthy
✅ Armitage vLLM is healthy
✅ LiteLLM proxy is healthy
```

### Step 6: Run Tests

**Context Window Test**
```bash
make test-context
# Or directly:
python3 tests/context_smoke.py
```

**Burst Load Test**
```bash
make test-burst
# Or directly:
python3 tests/burst_test.py
```

## Post-Deployment Verification

### Check vLLM Logs
```bash
# Wintermute
docker logs vllm-wintermute | grep -i "max-model-len\|kv-cache\|max-num-seqs"

# Armitage
docker logs vllm-armitage | grep -i "max-model-len\|kv-cache\|max-num-seqs"
```

Expected log entries:
- `max_model_len: 16384` (Wintermute) or `8192` (Armitage)
- `kv_cache_dtype: fp8`
- `max_num_seqs: 2` (Wintermute) or `1` (Armitage)

### Test API Endpoints

**Direct vLLM endpoints:**
```bash
# Wintermute
curl http://wintermute.tailnet.local:8000/v1/models

# Armitage
curl http://armitage.tailnet.local:8000/v1/models
```

**Via LiteLLM proxy:**
```bash
# List available models
curl http://motoko.tailnet.local:8000/v1/models

# Test Wintermute model
curl http://motoko.tailnet.local:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $LITELLM_TOKEN" \
  -d '{
    "model": "llama31-8b-wintermute",
    "messages": [{"role": "user", "content": "Hello"}],
    "max_tokens": 100
  }'
```

### Monitor GPU Memory
```bash
# On Windows devices
nvidia-smi

# Check for memory pressure
# Should see ~92% utilization on Wintermute, ~90% on Armitage
```

## Troubleshooting

If you encounter issues, see `docs/vLLM_CONTEXT_WINDOW_GUIDE.md` for detailed troubleshooting steps.

**Quick fixes:**
- OOM at startup → Reduce `max_model_len` by 25% in config.yml
- Random crashes → Change `kv_cache_dtype` to `fp16`
- High latency → Reduce `max_num_seqs` to 1

## Rollback (if needed)

If deployment causes issues:

```bash
# Rollback Wintermute
make rollback-wintermute

# Rollback Armitage
make rollback-armitage

# Rollback LiteLLM
make rollback-proxy
```

Then restart services manually.

## Success Criteria

- [ ] Both vLLM containers start without OOM errors
- [ ] Health checks pass for all services
- [ ] Context smoke test completes successfully
- [ ] Burst test completes with ≤1 error
- [ ] GPU memory utilization is within expected ranges
- [ ] No CUDA errors in logs
- [ ] API endpoints respond correctly

## Next Steps After Successful Deployment

1. Monitor for 24-48 hours for stability
2. Gradually increase limits if memory allows
3. Document any device-specific optimizations
4. Update monitoring dashboards if applicable

