# ✅ Ready for Deployment

## Summary
All Wintermute model configuration issues have been fixed:
- ✅ Device config updated
- ✅ PowerShell script updated  
- ✅ Bash script updated
- ✅ LiteLLM template fixed

## Quick Deploy (Run from ansible/ directory)

```bash
cd ~/miket-infra-devices/ansible

# 1. Deploy Wintermute scripts
ansible-playbook -i inventory/hosts.yml \
  playbooks/remote/wintermute-vllm-deploy-scripts.yml \
  --limit wintermute \
  --ask-vault-pass

# 2. Restart vLLM on Wintermute (run on Wintermute)
cd C:\Users\mdt\dev\wintermute\scripts
.\Start-VLLM.ps1 -Action Restart

# 3. Redeploy LiteLLM (from ansible/ directory)
cd ~/miket-infra-devices/ansible
ansible-playbook -i inventory/hosts.yml \
  playbooks/motoko/deploy-litellm.yml \
  --limit motoko \
  --connection=local

# 4. Verify
curl http://wintermute.tail2e55fe.ts.net:8000/v1/models | jq '.data[].id'
```

See `docs/WINTERMUTE_DEPLOYMENT_STEPS.md` for detailed instructions.
