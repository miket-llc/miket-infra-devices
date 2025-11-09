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
