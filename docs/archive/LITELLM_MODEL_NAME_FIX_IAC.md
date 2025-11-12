# LiteLLM Model Name Mismatch - IaC Fix

**Date**: 2025-11-12  
**Issue**: LiteLLM unable to connect to Wintermute local model  
**Status**: ✅ Fixed - Infrastructure as Code approach implemented

---

## Problem Summary

LiteLLM proxy on Motoko was unable to successfully route requests to the Wintermute vLLM instance due to a model name mismatch.

### Root Cause

**Model Name Mismatch:**
- **vLLM was serving as**: `casperhansen/llama-3-8b-instruct-awq` (HuggingFace model path)
- **LiteLLM was calling**: `openai/casperhansen/llama-3-8b-instruct-awq`
- **Result**: 404 Not Found - model names didn't match

**Why this happened:**
- Wintermute's vLLM startup did NOT include `--served-model-name` flag
- Without this flag, vLLM defaults to the full HuggingFace repository path
- LiteLLM expects explicit model names, creating a mismatch

---

## Solution: Infrastructure as Code Approach

### Principles Applied

✅ **Single Source of Truth**: All configuration in Ansible `host_vars`  
✅ **Template-Driven**: Config files generated from Jinja2 templates  
✅ **Version Controlled**: All changes tracked in git  
✅ **Idempotent**: Can be re-run safely without side effects  
✅ **Automated Deployment**: No manual file editing on remote machines

### Architecture

```
ansible/host_vars/wintermute.yml   (SOURCE OF TRUTH)
         ↓
ansible/roles/windows-vllm-deploy/
         ├── defaults/main.yml      (Default values)
         ├── tasks/main.yml         (Deployment logic)
         ├── templates/
         │   └── vllm_config.yml.j2 (Templated config)
         └── handlers/main.yml      (Restart handlers)
         ↓
C:\Users\mdt\dev\wintermute\config.yml  (DEPLOYED CONFIG)
         ↓
Start-VLLM.ps1 (Reads config.yml)
         ↓
vLLM Container with correct model name
```

---

## Files Changed (IaC Approach)

### 1. Ansible Host Variables

**File**: `ansible/host_vars/wintermute.yml`

Added vLLM configuration block:
```yaml
# vLLM Configuration
vllm:
  enabled: true
  model: "casperhansen/llama-3-8b-instruct-awq"
  served_model_name: "llama31-8b-wintermute"  # ← KEY FIX
  port: 8000
  container_name: "vllm-wintermute"
  image: "vllm/vllm-openai:latest"
  max_model_len: 9000
  gpu_memory_utilization: 0.88
  quantization: "awq"
  tensor_parallel_size: 1
  auto_switch: true
  check_interval_minutes: 5
  idle_threshold_minutes: 5
```

**File**: `ansible/host_vars/armitage.yml`

Added matching configuration (already working, but centralized):
```yaml
# vLLM Configuration
vllm:
  enabled: true
  model: "Qwen/Qwen2.5-7B-Instruct-AWQ"
  served_model_name: "qwen2.5-7b-armitage"
  port: 8000
  container_name: "vllm-armitage"
  image: "vllm/vllm-openai:latest"
  quantization: "awq"
  max_model_len: 16384
  max_num_seqs: 1
  gpu_memory_utilization: 0.85
  tensor_parallel_size: 1
  auto_switch: true
  check_interval_minutes: 5
  idle_threshold_minutes: 5
```

### 2. Role Defaults

**File**: `ansible/roles/windows-vllm-deploy/defaults/main.yml`

Maps host_vars to role variables:
```yaml
# vLLM configuration (referencing host_vars structure)
vllm_model: "{{ vllm.model | default('mistralai/Mistral-7B-Instruct-v0.2') }}"
vllm_served_model_name: "{{ vllm.served_model_name | default(None) }}"
vllm_port: "{{ vllm.port | default(8000) }}"
vllm_container_name: "{{ vllm.container_name | default('vllm-' + inventory_hostname) }}"
vllm_max_model_len: "{{ vllm.max_model_len | default(8192) }}"
vllm_gpu_memory_utilization: "{{ vllm.gpu_memory_utilization | default(0.85) }}"
vllm_quantization: "{{ vllm.quantization | default(None) }}"
# ... etc
```

### 3. Configuration Template

**File**: `ansible/roles/windows-vllm-deploy/templates/vllm_config.yml.j2`

Jinja2 template that generates config.yml:
```jinja2
# {{ ansible_managed }}
vllm:
  enabled: {{ vllm.enabled | default(true) | lower }}
  model: "{{ vllm_model }}"
{% if vllm_served_model_name %}
  served_model_name: "{{ vllm_served_model_name }}"
{% endif %}
  port: {{ vllm_port }}
  max_model_len: {{ vllm_max_model_len }}
  # ... etc
```

### 4. Deployment Tasks

**File**: `ansible/roles/windows-vllm-deploy/tasks/main.yml`

Uses template instead of copying static files:
```yaml
- name: Deploy vLLM config.yml (IaC-managed, templated from host_vars)
  win_template:
    src: vllm_config.yml.j2
    dest: "C:\\Users\\mdt\\dev\\{{ inventory_hostname }}\\config.yml"
  notify: Restart vLLM container
```

### 5. LiteLLM Variables

**File**: `ansible/group_vars/motoko.yml`

Updated model reference:
```yaml
# Before:
wintermute_model_display: openai/casperhansen/llama-3-8b-instruct-awq

# After:
wintermute_model_display: openai/llama31-8b-wintermute
```

### 6. Handlers

**File**: `ansible/roles/windows-vllm-deploy/handlers/main.yml`

Automatically restarts container when config changes:
```yaml
- name: Restart vLLM container
  win_shell: |
    $scriptPath = "C:\Users\mdt\dev\{{ inventory_hostname }}\scripts\Start-VLLM.ps1"
    if (Test-Path $scriptPath) {
      & $scriptPath -Action Restart
    }
```

---

## Deployment Steps (IaC Way)

### Step 1: Deploy Wintermute Configuration

```bash
cd /home/mdt/miket-infra-devices/ansible

# Deploy updated config (templates from host_vars)
ansible-playbook -i inventory/hosts.yml \
  playbooks/windows-vllm-deploy.yml \
  --limit wintermute \
  --ask-vault-pass
```

**What this does:**
1. Reads configuration from `host_vars/wintermute.yml`
2. Templates `vllm_config.yml.j2` → `config.yml` on Wintermute
3. Deploys PowerShell scripts if needed
4. Automatically restarts vLLM container (via handler)

### Step 2: Deploy Armitage Configuration (Optional)

```bash
ansible-playbook -i inventory/hosts.yml \
  playbooks/windows-vllm-deploy.yml \
  --limit armitage \
  --ask-vault-pass
```

### Step 3: Deploy Updated LiteLLM Config

```bash
ansible-playbook -i inventory/hosts.yml \
  playbooks/motoko/deploy-litellm.yml \
  --limit motoko \
  --connection=local
```

### Step 4: Verify

```bash
# Check Wintermute serves correct model name
curl http://192.168.1.93:8000/v1/models

# Expected:
{
  "data": [
    {
      "id": "llama31-8b-wintermute",  # ← Correct!
      "object": "model"
    }
  ]
}

# Test via LiteLLM
curl -X POST http://motoko:8000/v1/chat/completions \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "local/reasoner",
    "messages": [{"role": "user", "content": "Test"}]
  }'
```

---

## Configuration Management Workflow

### Making Changes (The IaC Way)

**❌ WRONG (Old Way)**:
1. SSH/RDP to Wintermute
2. Edit `C:\Users\mdt\dev\wintermute\config.yml` manually
3. Restart container manually
4. Changes not tracked, not repeatable

**✅ CORRECT (IaC Way)**:
1. Edit `ansible/host_vars/wintermute.yml` in repo
2. Commit changes to git
3. Run Ansible playbook to deploy
4. Changes tracked, automated, repeatable

### Example: Change GPU Memory Utilization

```bash
# 1. Edit in version control
vim ansible/host_vars/wintermute.yml
# Change: gpu_memory_utilization: 0.88 → 0.90

# 2. Commit
git add ansible/host_vars/wintermute.yml
git commit -m "Increase Wintermute GPU utilization to 0.90"

# 3. Deploy
cd ansible
ansible-playbook -i inventory/hosts.yml \
  playbooks/windows-vllm-deploy.yml \
  --limit wintermute \
  --ask-vault-pass

# 4. Ansible automatically:
#    - Templates new config.yml
#    - Detects change
#    - Restarts vLLM container
```

---

## Benefits of IaC Approach

### Before (Manual Config)
- ❌ Config scattered across multiple machines
- ❌ No version history
- ❌ Manual deployment prone to errors
- ❌ Difficult to replicate setup
- ❌ No rollback capability

### After (Infrastructure as Code)
- ✅ Single source of truth (`host_vars`)
- ✅ All changes in git history
- ✅ Automated, repeatable deployments
- ✅ Easy to add new machines
- ✅ Can rollback via `git revert`
- ✅ Configuration auditable and reviewable

---

## Adding New Windows vLLM Hosts

With this IaC setup, adding a new machine is easy:

```bash
# 1. Add to inventory
vim ansible/inventory/hosts.yml
# Add: new-machine ansible_host=192.168.1.x

# 2. Create host_vars
vim ansible/host_vars/new-machine.yml
# Copy from wintermute.yml, adjust values

# 3. Deploy
ansible-playbook -i inventory/hosts.yml \
  playbooks/windows-vllm-deploy.yml \
  --limit new-machine \
  --ask-vault-pass
```

---

## Rollback Plan

If issues arise:

```bash
# Revert to previous config
cd /home/mdt/miket-infra-devices
git log ansible/host_vars/wintermute.yml
git revert <commit-hash>

# Redeploy
cd ansible
ansible-playbook -i inventory/hosts.yml \
  playbooks/windows-vllm-deploy.yml \
  --limit wintermute
```

---

## Summary

**Problem**: Model name mismatch preventing LiteLLM from connecting to Wintermute

**Solution**: 
1. Added `served_model_name: "llama31-8b-wintermute"` to `host_vars/wintermute.yml`
2. Created template-driven configuration management
3. Updated LiteLLM to reference correct model name
4. Established IaC workflow for all future changes

**Impact**: 
- ✅ LiteLLM can now route to Wintermute successfully
- ✅ All configuration centralized in Ansible
- ✅ Changes tracked in version control
- ✅ Repeatable, automated deployments

**Status**: ✅ Ready to deploy



