# AI Fabric Runtime Operations

**Status:** Production  
**Last Updated:** 2025-11-30  
**Owner:** miket-infra-devices team

## Overview

This runbook covers operational procedures for the distributed AI Fabric that provides LLM inference across the miket-infra device estate.

### Architecture Summary

- **Gateway:** LiteLLM proxy on motoko (port 8000)
- **Backends:** vLLM instances on motoko, wintermute, armitage
- **Network:** All traffic over Tailscale VPN (pangolin-vega.ts.net)
- **Secrets:** Azure Key Vault → `/podman/apps/litellm/.env`

### Logical Roles (Platform Contract)

Applications request these logical roles, not physical models:

| Role | Backend | Model | Use Case |
|------|---------|-------|----------|
| `chat-fast` | armitage | Qwen2.5-7B-AWQ | Fast, low-latency chat |
| `chat-deep` | wintermute | Llama-3-8B-AWQ | Deeper reasoning, longer context |
| `embeddings-general` | motoko | BGE-base-en-v1.5 | Text embeddings |

Legacy aliases: `local/chat`, `local/reasoner`, `local/embed`

---

## Health Checks

### Quick Status

```bash
# Check all backends
/home/mdt/.cursor/worktrees/miket-infra-devices__SSH__motoko_/vit/scripts/health/check_vllm_backends.sh

# Check specific backend
/home/mdt/.cursor/worktrees/miket-infra-devices__SSH__motoko_/vit/scripts/health/check_vllm_backends.sh motoko
```

### Smoke Test

```bash
# Run end-to-end validation
cd /home/mdt/.cursor/worktrees/miket-infra-devices__SSH__motoko_/vit
python3 scripts/tests/ai_fabric_smoke_test.py
```

### Manual Verification

**LiteLLM Proxy:**
```bash
# List available models
curl -s http://127.0.0.1:8000/v1/models | jq -r '.data[].id'

# Test chat completion
curl -X POST http://127.0.0.1:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"chat-fast","messages":[{"role":"user","content":"hi"}],"max_tokens":10}'

# Test embeddings
curl -X POST http://127.0.0.1:8000/v1/embeddings \
  -H "Content-Type: application/json" \
  -d '{"model":"embeddings-general","input":"test"}'
```

**vLLM Backends:**
```bash
# Motoko embeddings (local)
curl -s http://127.0.0.1:8200/health
curl -s http://127.0.0.1:8200/v1/models

# Wintermute (via tailnet)
curl -s http://wintermute.pangolin-vega.ts.net:8000/health

# Armitage (via tailnet)
curl -s http://armitage.pangolin-vega.ts.net:8000/health
```

---

## Service Management

### LiteLLM Proxy (motoko)

**Status:**
```bash
sudo systemctl status litellm
sudo podman ps | grep litellm
```

**Restart:**
```bash
# Via Ansible (recommended)
cd /home/mdt/.cursor/worktrees/miket-infra-devices__SSH__motoko_/vit/ansible
ansible-playbook playbooks/motoko/deploy-litellm.yml

# Manual restart
sudo systemctl restart litellm
# OR
cd /podman/apps/litellm && sudo podman-compose restart
```

**Logs:**
```bash
sudo podman logs -f litellm
sudo journalctl -u litellm -f
```

**Config:**
- Template: `ansible/roles/litellm_proxy/templates/litellm.config.yaml.j2`
- Deployed: `/podman/apps/litellm/config.yaml`
- Secrets: `/podman/apps/litellm/.env` (from Azure Key Vault)

### vLLM on Motoko (embeddings)

**Status:**
```bash
sudo podman ps | grep vllm
sudo systemctl status vllm-stack  # May not be enabled
```

**Restart:**
```bash
# Via Ansible
cd /home/mdt/.cursor/worktrees/miket-infra-devices__SSH__motoko_/vit/ansible
ansible-playbook playbooks/motoko/deploy-vllm.yml

# Manual restart
cd /podman/apps/vllm && sudo podman-compose restart
```

**Logs:**
```bash
sudo podman logs -f vllm-embeddings-motoko
```

### vLLM on Windows Workstations (wintermute, armitage)

**Note:** These workstations use Podman Desktop with WSL2 backend. External access requires Windows port proxy rules.

**Check if online:**
```bash
ping -c 2 wintermute.pangolin-vega.ts.net
ping -c 2 armitage.pangolin-vega.ts.net
```

**Deploy/Update (preferred method):**
```bash
cd /home/mdt/.cursor/worktrees/miket-infra-devices__SSH__motoko_/vit/ansible

# Deploy to specific host
ansible-playbook playbooks/deploy-vllm-windows.yml --limit wintermute
ansible-playbook playbooks/deploy-vllm-windows.yml --limit armitage

# Deploy to all Windows workstations
ansible-playbook playbooks/deploy-vllm-windows.yml
```

**Manual start (on Windows machine):**
```powershell
# On wintermute or armitage
powershell -ExecutionPolicy Bypass -File C:\Users\mdt\vllm-start.ps1

# Check container status
podman ps | findstr vllm

# Check port proxy (required for Tailscale access)
netsh interface portproxy show v4tov4
```

**Port Proxy Setup (if missing):**
```powershell
# Get WSL2 IP
$wslIP = podman machine ssh ip -4 addr show eth0 | Select-String 'inet (\d+\.\d+\.\d+\.\d+)' | % { $_.Matches.Groups[1].Value }

# Add port proxy rule
netsh interface portproxy add v4tov4 listenport=8000 listenaddress=0.0.0.0 connectport=8000 connectaddress=$wslIP
```

---

## Troubleshooting

### LiteLLM Returns 500 Errors

**Symptoms:** `APIError: Connection error` when calling chat models

**Cause:** Backend vLLM service is offline (wintermute/armitage powered off)

**Resolution:**
1. Check which backend is down: `scripts/health/check_vllm_backends.sh`
2. Power on the workstation if needed
3. Start vLLM container on Windows:
   ```powershell
   powershell -File C:\Users\mdt\dev\<hostname>\scripts\Start-VLLM.ps1 -Action Start
   ```
4. Verify with health check again

**Alternative:** Use OpenAI fallback by explicitly requesting `openai/strong` model

### Embeddings Return 404 Error

**Symptoms:** `The model 'bge-base-en-v1.5' does not exist`

**Cause:** Model name mismatch between litellm config and vLLM

**Resolution:**
1. Check vLLM models: `curl http://127.0.0.1:8200/v1/models | jq -r '.data[0].id'`
2. Verify litellm config matches: `sudo cat /podman/apps/litellm/config.yaml | grep bge`
3. If mismatch, update config and redeploy:
   ```bash
   cd /home/mdt/.cursor/worktrees/miket-infra-devices__SSH__motoko_/vit/ansible
   ansible-playbook playbooks/motoko/deploy-litellm.yml --tags config
   ```

### Slow Response Times

**Symptoms:** Requests take >10s to complete

**Possible Causes:**
1. **Model loading:** vLLM is loading model into VRAM (first request after start)
   - Wait 30-60s, retry
   - Check logs: `sudo podman logs vllm-embeddings-motoko --tail 50`

2. **GPU memory pressure:** Another process using GPU
   - Check: `nvidia-smi`
   - Stop competing processes or restart vLLM

3. **Network latency:** Tailscale connectivity issues
   - Test: `ping -c 10 wintermute.pangolin-vega.ts.net`
   - Check Tailscale status: `sudo tailscale status`

### LiteLLM Won't Start

**Symptoms:** Container restarts immediately or hangs

**Check logs:**
```bash
sudo podman logs litellm --tail 100
```

**Common issues:**
1. **Config syntax error:** Validate YAML:
   ```bash
   sudo podman run --rm -v /podman/apps/litellm/config.yaml:/config.yaml:ro \
     ghcr.io/berriai/litellm:main-v1.55.4 \
     python -c "import yaml; yaml.safe_load(open('/config.yaml'))"
   ```

2. **Missing secrets:** Check `.env` file exists and has values:
   ```bash
   sudo ls -la /podman/apps/litellm/.env
   sudo cat /podman/apps/litellm/.env | grep -c "="  # Should be > 0
   ```

3. **Port conflict:** Check if port 8000 is already in use:
   ```bash
   sudo ss -tlnp | grep 8000
   ```

---

## Configuration Updates

### Adding a New Model

1. **Add backend vLLM instance** (if needed):
   - Update `ansible/host_vars/<hostname>.yml` with vLLM config
   - Deploy: `ansible-playbook playbooks/<host>/deploy-vllm.yml`

2. **Register in litellm:**
   - Edit `ansible/roles/litellm_proxy/templates/litellm.config.yaml.j2`
   - Add model to `model_list` section
   - Deploy: `ansible-playbook playbooks/motoko/deploy-litellm.yml --tags config`

3. **Verify:**
   ```bash
   curl -s http://127.0.0.1:8000/v1/models | jq -r '.data[].id' | grep <new-model>
   ```

### Updating Secrets

**Pull latest from Azure Key Vault:**
```bash
cd /home/mdt/.cursor/worktrees/miket-infra-devices__SSH__motoko_/vit/ansible
ansible-playbook playbooks/secrets-sync.yml --limit motoko
```

**Secrets are stored in:**
- AKV Source: `kv-miket-ops`
- Deployed: `/podman/apps/litellm/.env`
- Mapping: `ansible/secrets-map.yml`

**After update:**
```bash
# Restart litellm to pick up new secrets
sudo systemctl restart litellm
```

### Changing Backend URLs

**Update host_vars:**
```yaml
# ansible/group_vars/motoko.yml
armitage_base_url: "http://armitage.pangolin-vega.ts.net:8000/v1"
wintermute_base_url: "http://wintermute.pangolin-vega.ts.net:8000/v1"
motoko_embed_base_url: "http://motoko.pangolin-vega.ts.net:8200/v1"
```

**Redeploy:**
```bash
ansible-playbook playbooks/motoko/deploy-litellm.yml --tags config
```

---

## Monitoring

### Key Metrics

**Health check frequency:** Every 5 minutes (via cron or systemd timer - TBD)

**Alerting thresholds:**
- LiteLLM down: CRITICAL
- ≥2 backends down: WARNING
- Embeddings down: WARNING (motoko is always-on)
- Chat backends down: INFO (workstations may be off)

### Logs

**Centralized logging:** `/var/log/ai-fabric/` (TBD)

**Current log locations:**
- LiteLLM: `sudo podman logs litellm`
- vLLM (motoko): `sudo podman logs vllm-embeddings-motoko`
- vLLM (Windows): Check Docker Desktop logs or `docker logs vllm-<hostname>`

---

## Failure Modes & Recovery

### Complete Gateway Failure (LiteLLM Down)

**Impact:** All AI fabric requests fail

**Recovery:**
1. Restart litellm: `sudo systemctl restart litellm`
2. Check logs: `sudo podman logs litellm --tail 50`
3. If config issue, rollback or fix config
4. Verify with smoke test

**Mitigation:** Run litellm on secondary host (TBD)

### Single Backend Failure

**Impact:** Requests to that role may fail or be slow (routing to fallback)

**Recovery:**
1. Identify failed backend: `scripts/health/check_vllm_backends.sh`
2. For Windows: Power on machine, start vLLM
3. For motoko: Restart vLLM container
4. Verify health

**Mitigation:** LiteLLM should route to OpenAI fallback automatically

### Network Partition (Tailscale Down)

**Impact:** Cross-host communication fails

**Recovery:**
1. Check Tailscale: `sudo tailscale status`
2. Restart if needed: `sudo systemctl restart tailscaled`
3. Verify connectivity: `ping wintermute.pangolin-vega.ts.net`

**Mitigation:** Embeddings on motoko still work (local), OpenAI fallback available

---

## Runbook Testing

**Test this runbook:** Quarterly or after major changes

**Test procedure:**
1. Run all health checks
2. Simulate failure (stop vLLM on one backend)
3. Verify failure detection
4. Follow recovery procedure
5. Verify recovery
6. Update runbook if procedures changed

---

## References

- **Platform Contract:** See miket-infra `docs/reference/AI_FABRIC_PLATFORM_CONTRACT.md`
- **Architecture:** See miket-infra `docs/architecture/components/AI_FABRIC_SERVICE.md`
- **Ansible Roles:**
  - `ansible/roles/litellm_proxy/`
  - `ansible/roles/vllm-motoko/`
  - `ansible/roles/windows-vllm-deploy/`
- **Health Scripts:**
  - `scripts/health/check_vllm_backends.sh`
  - `scripts/tests/ai_fabric_smoke_test.py`

---

## Change Log

| Date | Change | Author |
|------|--------|--------|
| 2025-11-30 | Initial version | miket-infra-devices team |

