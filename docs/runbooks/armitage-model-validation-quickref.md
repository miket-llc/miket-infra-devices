# Armitage Model Validation - Quick Reference

## Quick Commands

### Run Full Validation
```bash
# From Motoko
cd ~/miket-infra-devices
./scripts/Validate-Armitage-Model.sh
```

### Check Model via API
```bash
curl http://armitage.pangolin-vega.ts.net:8000/v1/models
```

### Check LiteLLM Proxy
```bash
curl http://localhost:4000/v1/models
```

### Update Model via Ansible
```bash
ansible-playbook -i ansible/inventory/hosts.yml \
  ansible/playbooks/armitage-vllm-validate.yml \
  --limit armitage \
  --ask-vault-pass
```

## Expected Configuration

### vLLM Parameters
- Model: `Qwen/Qwen2.5-7B-Instruct`
- Dtype: `bf16`
- Max Model Length: `8192`
- Max Num Seqs: `2`
- GPU Memory Utilization: `0.9`
- Served Model Name: `qwen2.5-7b-armitage`
- Port: `8000`

### LiteLLM Route
- Model Name: `qwen2.5-7b-armitage`
- API Base: `http://armitage.pangolin-vega.ts.net:8000/v1`
- Max Input Tokens: `7000`
- Max Output Tokens: `768`
- TPM: `80000`
- RPM: `40`
- Concurrency: `1-2`

## Troubleshooting Quick Fixes

### Model Not Running
```powershell
# On Armitage
.\Start-VLLM.ps1 -Action Restart
```

### OOM Errors
Update `config.yml`:
```yaml
vllm:
  max_model_len: 4096
  max_num_seqs: 1
  gpu_memory_utilization: 0.8
```

### Connection Issues
```bash
# Test connectivity
ansible armitage -i ansible/inventory/hosts.yml -m win_ping
ping armitage.pangolin-vega.ts.net
```

### LiteLLM Not Routing
```bash
# Restart LiteLLM
sudo systemctl restart litellm
# Check logs
sudo journalctl -u litellm -f
```

## Files Modified

- `devices/armitage/config.yml` - Updated model configuration
- `devices/armitage/scripts/Start-VLLM.ps1` - Updated launch parameters
- `ansible/playbooks/armitage-vllm-setup.yml` - Updated default model
- `ansible/playbooks/armitage-vllm-validate.yml` - New validation playbook
- `configs/litellm/config.yaml.template` - LiteLLM configuration template
- `scripts/Validate-Armitage-Model.sh` - Comprehensive validation script

## Documentation

- Full guide: `docs/runbooks/armitage-model-validation.md`
- vLLM setup: `docs/runbooks/armitage-vllm.md`
- Docker NVIDIA debug: `docs/runbooks/armitage-docker-nvidia-debug.md`

