# Quick Deployment Guide - LiteLLM Model Name Fix

## What Was Fixed

**Issue**: LiteLLM couldn't connect to Wintermute because the model name didn't match.

**Root Cause**: Wintermute vLLM wasn't using `--served-model-name` flag, so it served as `casperhansen/llama-3-8b-instruct-awq` but LiteLLM expected `llama31-8b-wintermute`.

**Solution**: Implemented Infrastructure as Code (IaC) approach:
- Configuration now lives in `ansible/host_vars/` (single source of truth)
- Config files templated via Jinja2
- Automated deployment via Ansible

---

## Files Changed

### Infrastructure as Code (Source of Truth)
- `ansible/host_vars/wintermute.yml` - Added vLLM config with `served_model_name`
- `ansible/host_vars/armitage.yml` - Centralized vLLM config
- `ansible/group_vars/motoko.yml` - Updated LiteLLM model reference
- `ansible/roles/windows-vllm-deploy/defaults/main.yml` - Added vLLM variable mappings
- `ansible/roles/windows-vllm-deploy/tasks/main.yml` - Use templates instead of static files
- `ansible/roles/windows-vllm-deploy/templates/vllm_config.yml.j2` - New config template
- `ansible/roles/windows-vllm-deploy/handlers/main.yml` - Auto-restart handler

### Documentation
- `LITELLM_MODEL_NAME_FIX_IAC.md` - Full technical documentation
- `DEPLOYMENT_GUIDE_LITELLM_FIX.md` - This quick guide

---

## Deploy Now (3 Commands)

```bash
cd /home/mdt/miket-infra-devices/ansible

# 1. Deploy Wintermute config (fixes the model name issue)
ansible-playbook -i inventory/hosts.yml \
  playbooks/windows-vllm-deploy.yml \
  --limit wintermute \
  --ask-vault-pass

# 2. Deploy Armitage config (optional, centralizes config)
ansible-playbook -i inventory/hosts.yml \
  playbooks/windows-vllm-deploy.yml \
  --limit armitage \
  --ask-vault-pass

# 3. Update LiteLLM proxy on Motoko
ansible-playbook -i inventory/hosts.yml \
  playbooks/motoko/deploy-litellm.yml \
  --limit motoko \
  --connection=local
```

---

## Verify It Works

```bash
# 1. Check Wintermute serves with correct name
curl http://192.168.1.93:8000/v1/models
# Should show: "id": "llama31-8b-wintermute"

# 2. Test LiteLLM can reach Wintermute
curl -X POST http://localhost:8000/v1/chat/completions \
  -H "Authorization: Bearer YOUR_LITELLM_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "local/reasoner",
    "messages": [{"role": "user", "content": "Hello"}]
  }'
# Should get a valid response, not 404
```

---

## Future Changes (The IaC Way)

**To change vLLM settings:**

1. Edit `ansible/host_vars/wintermute.yml` (or armitage.yml)
2. Run playbook to deploy
3. Ansible automatically restarts container

**Example:**
```bash
# Change GPU utilization
vim ansible/host_vars/wintermute.yml
# Update: gpu_memory_utilization: 0.88 → 0.90

# Deploy
cd ansible
ansible-playbook -i inventory/hosts.yml \
  playbooks/windows-vllm-deploy.yml \
  --limit wintermute \
  --ask-vault-pass
```

---

## Key Principle

**❌ DON'T**: Edit config files on remote machines manually  
**✅ DO**: Edit `ansible/host_vars/`, commit to git, run Ansible

This ensures:
- All changes tracked in version control
- Can rollback anytime
- Repeatable deployments
- Configuration auditable

---

## Rollback If Needed

```bash
# Find previous version
git log ansible/host_vars/wintermute.yml

# Revert to previous
git revert <commit-hash>

# Redeploy
cd ansible
ansible-playbook -i inventory/hosts.yml \
  playbooks/windows-vllm-deploy.yml \
  --limit wintermute
```

---

## Questions?

See `LITELLM_MODEL_NAME_FIX_IAC.md` for full technical details.



