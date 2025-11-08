# Wintermute Model Configuration Fix

## Problem Identified

Wintermute was configured to run **Llama 3.1 8B Instruct AWQ** (as the reasoner model), but several configuration files had mismatches pointing to **Qwen 2.5 7B Instruct AWQ** instead.

## Issues Found

1. **`devices/wintermute/config.yml`**: Said `Qwen/Qwen2.5-7B-Instruct-AWQ` ❌
2. **`devices/wintermute/scripts/Start-VLLM.ps1`**: Hardcoded default `Qwen/Qwen2.5-7B-Instruct-AWQ` ❌
3. **`devices/wintermute/scripts/vllm.sh`**: Defaulted to `Qwen/Qwen2.5-7B-Instruct-AWQ` ❌
4. **`ansible/roles/litellm_proxy/templates/litellm.config.yaml.j2`**: Hardcoded `openai/Qwen/Qwen2.5-7B-Instruct-AWQ` instead of using `wintermute_model_display` variable ❌

## What Was Correct

- **`ansible/group_vars/motoko.yml`**: Correctly configured `wintermute_model_hf_id: "meta-llama/Meta-Llama-3.1-8B-Instruct-AWQ"` ✅
- **`ansible/playbooks/remote/wintermute-vllm-deploy-scripts.yml`**: Correctly defaults to `meta-llama/Meta-Llama-3.1-8B-Instruct-AWQ` ✅

## Fixes Applied

1. ✅ Updated `devices/wintermute/config.yml` to use `meta-llama/Meta-Llama-3.1-8B-Instruct-AWQ`
2. ✅ Updated `devices/wintermute/scripts/Start-VLLM.ps1` default to `meta-llama/Meta-Llama-3.1-8B-Instruct-AWQ`
3. ✅ Updated `devices/wintermute/scripts/vllm.sh` default to `meta-llama/Meta-Llama-3.1-8B-Instruct-AWQ`
4. ✅ Fixed LiteLLM template to use `{{ wintermute_model_display }}` variable instead of hardcoded Qwen

## Current Configuration

**Wintermute Model:** `meta-llama/Meta-Llama-3.1-8B-Instruct-AWQ`
- **Purpose:** Reasoner fallback model
- **VRAM Usage:** ~5GB (with 0.90 GPU utilization)
- **Max Context:** 8192 tokens
- **LiteLLM Name:** `local/reasoner`

## Next Steps

1. **Redeploy Wintermute vLLM** to pick up the corrected configuration:
   ```bash
   cd ~/miket-infra-devices/ansible
   ansible-playbook -i inventory/hosts.yml \
     playbooks/remote/wintermute-vllm-deploy-scripts.yml \
     --limit wintermute
   ```

2. **Restart vLLM container** on Wintermute (if already running):
   ```powershell
   # On Wintermute
   .\Start-VLLM.ps1 -Action Restart
   ```

3. **Redeploy LiteLLM** to pick up the template fix:
   ```bash
   cd ~/miket-infra-devices/ansible
   ansible-playbook -i inventory/hosts.yml \
     playbooks/motoko/deploy-litellm.yml \
     --limit motoko \
     --connection=local
   ```

4. **Verify** the model is correct:
   ```bash
   curl http://wintermute.tail2e55fe.ts.net:8000/v1/models
   ```

## Why This Matters

- **LiteLLM routing** expects Llama 3.1 8B on Wintermute
- **Fallback chain** relies on the correct model being available
- **Model capabilities** differ between Qwen and Llama
- **Consistency** across all configuration files is critical

