# LiteLLM Llama Model 404 Error - Diagnosis & Fix

**Date**: 2025-01-XX  
**Issue**: LiteLLM returning 404 for `llama31-8b-wintermute` model  
**Status**: ✅ Fixed - Script updated, ready for deployment

---

## Problem Summary

The Obsidian plugin was trying to use Llama models for reasoning tasks but getting 404 errors:

```
404 litellm.NotFoundError: The model `llama31-8b-wintermute` does not exist
```

After this error, the plugin falls back to Qwen for all tasks.

---

## Root Cause Analysis

### Investigation Results

1. **LiteLLM `/v1/models` endpoint** ✅
   - Shows `llama31-8b-wintermute` is available
   - Model is registered in LiteLLM configuration

2. **LiteLLM `/model/info` endpoint** ✅
   - Shows `llama31-8b-wintermute` is configured
   - Points to backend: `http://192.168.1.93:8000/v1`
   - Expects model: `openai/llama31-8b-wintermute`

3. **Backend vLLM server** ❌
   - **Actual model name**: `casperhansen/llama-3-8b-instruct-awq`
   - **Expected model name**: `llama31-8b-wintermute`
   - **Mismatch**: vLLM is serving with the HuggingFace model path instead of the configured alias

4. **Configuration** ✅
   - `ansible/host_vars/wintermute.yml` has `served_model_name: "llama31-8b-wintermute"`
   - `ansible/group_vars/motoko.yml` has `wintermute_model_display: openai/llama31-8b-wintermute`

### The Problem

The vLLM server on Wintermute was started **without** the `--served-model-name` flag, so it defaults to serving the model with its HuggingFace repository path (`casperhansen/llama-3-8b-instruct-awq`) instead of the configured alias (`llama31-8b-wintermute`).

When LiteLLM tries to route a request to `openai/llama31-8b-wintermute`, it forwards it to the backend vLLM server, but the backend doesn't recognize that model name, causing a 404 error.

---

## Solution

### Fix Applied

Updated `devices/wintermute/scripts/Start-VLLM.ps1` to:

1. **Read `served_model_name` from config.yml**
   - Added parsing for `served_model_name` field
   - Stores it in `$Config.ServedModelName`

2. **Add `--served-model-name` flag to docker run command**
   - Only adds the flag if `ServedModelName` is set in config
   - This ensures vLLM serves the model with the correct name

3. **Display served model name in startup output**
   - Shows the configured served model name for verification

### Changes Made

**File**: `devices/wintermute/scripts/Start-VLLM.ps1`

1. Added `ServedModelName = $null` to default config hash
2. Added YAML parsing for `served_model_name` field
3. Added `--served-model-name` flag to docker run command
4. Added display of served model name in startup messages

**Comparison with Armitage**:
- Armitage's script already had this functionality ✅
- Wintermute's script was missing it ❌
- Now both are consistent ✅

---

## Deployment Instructions

### Step 1: Deploy Updated Script to Wintermute

```bash
cd /home/mdt/miket-infra-devices/ansible

ansible-playbook -i inventory/hosts.yml \
  playbooks/windows-vllm-deploy.yml \
  --limit wintermute \
  --ask-vault-pass
```

This will:
- Deploy the updated `Start-VLLM.ps1` script
- Deploy the `config.yml` with `served_model_name: "llama31-8b-wintermute"`

### Step 2: Restart vLLM Container on Wintermute

**Option A: Via PowerShell on Wintermute (Recommended)**
```powershell
cd C:\Users\mdt\dev\wintermute\scripts
.\Start-VLLM.ps1 -Action Restart
```

**Option B: Via Ansible**
```bash
ansible wintermute -i inventory/hosts.yml -m win_shell \
  -a "cd C:\Users\mdt\dev\wintermute\scripts; .\Start-VLLM.ps1 -Action Restart" \
  --ask-vault-pass
```

### Step 3: Verify vLLM Serves Correct Model Name

```bash
# Check what model name vLLM is serving
curl -s http://192.168.1.93:8000/v1/models | jq -r '.data[0].id'

# Expected output:
# llama31-8b-wintermute
```

### Step 4: Test LiteLLM Routing

```bash
# Test via LiteLLM
curl -X POST http://100.92.23.71:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "llama31-8b-wintermute",
    "messages": [{"role": "user", "content": "Hello"}],
    "max_tokens": 10
  }' | jq .

# Should return a successful response, not a 404
```

### Step 5: Verify Obsidian Plugin Can Use Llama

After the fix, your Obsidian plugin should:
1. Query `/v1/models` and find `llama31-8b-wintermute`
2. Successfully use it for reasoning tasks
3. No longer fall back to Qwen

---

## Verification Checklist

- [ ] Updated script deployed to Wintermute
- [ ] vLLM container restarted with new script
- [ ] vLLM serves model as `llama31-8b-wintermute` (not `casperhansen/llama-3-8b-instruct-awq`)
- [ ] LiteLLM can successfully route to `llama31-8b-wintermute`
- [ ] Obsidian plugin can use Llama models for reasoning
- [ ] No more 404 errors for `llama31-8b-wintermute`

---

## Technical Details

### How `--served-model-name` Works

When vLLM starts without `--served-model-name`:
- It serves the model using its HuggingFace repository path
- Example: `casperhansen/llama-3-8b-instruct-awq`

When vLLM starts with `--served-model-name llama31-8b-wintermute`:
- It serves the model using the specified alias
- The `/v1/models` endpoint returns: `{"id": "llama31-8b-wintermute", ...}`
- LiteLLM can then route requests using this name

### LiteLLM Configuration Flow

1. **LiteLLM config** (`litellm.config.yaml.j2`):
   ```yaml
   - model_name: llama31-8b-wintermute
     litellm_params:
       model: openai/llama31-8b-wintermute
       api_base: http://192.168.1.93:8000/v1
   ```

2. **LiteLLM receives request** for `llama31-8b-wintermute`

3. **LiteLLM forwards to backend** as `openai/llama31-8b-wintermute`

4. **vLLM must recognize** `llama31-8b-wintermute` as a valid model name

5. **Without `--served-model-name`**: vLLM only knows `casperhansen/llama-3-8b-instruct-awq` → 404 ❌

6. **With `--served-model-name`**: vLLM knows `llama31-8b-wintermute` → Success ✅

---

## Related Files

- `devices/wintermute/scripts/Start-VLLM.ps1` - Updated script
- `ansible/host_vars/wintermute.yml` - Configuration source
- `ansible/roles/litellm_proxy/templates/litellm.config.yaml.j2` - LiteLLM config template
- `ansible/group_vars/motoko.yml` - LiteLLM variables

---

## Summary

**Problem**: vLLM server serving model with wrong name, causing LiteLLM 404 errors

**Solution**: Updated PowerShell script to read and use `served_model_name` from config

**Status**: ✅ Script updated, ready for deployment

**Next Steps**: Deploy script, restart vLLM container, verify model name, test LiteLLM routing

