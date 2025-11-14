# Quick Reference: Modernization Implementation

## Files Created/Modified

### New Files
- `docs/ARCHITECTURE_REVIEW.md` - Comprehensive repository review
- `docs/migration/MIGRATION_PLAN.md` - motoko-devops consolidation plan
- `docs/IMPLEMENTATION_SUMMARY.md` - Implementation summary
- `ansible/roles/vllm-motoko/` - Complete vLLM role for Motoko
- `ansible/playbooks/motoko/deploy-vllm.yml` - vLLM deployment playbook

### Modified Files
- `ansible/ansible.cfg` - Added performance optimizations
- `ansible/host_vars/motoko.yml` - Added reasoning URL
- `ansible/roles/litellm_proxy/templates/litellm.config.yaml.j2` - Added reasoning model

---

## Quick Commands

### Deploy vLLM on Motoko
```bash
cd ~/miket-infra-devices
ansible-playbook -i ansible/inventory/hosts.yml \
  ansible/playbooks/motoko/deploy-vllm.yml \
  --limit motoko
```

### Test Ansible Performance
```bash
# Before optimization (baseline)
time ansible all -i ansible/inventory/hosts.yml -m ping

# After optimization (should be 2-3x faster)
time ansible all -i ansible/inventory/hosts.yml -m ping
```

### Check vLLM Services
```bash
# On Motoko
docker ps | grep vllm
curl http://localhost:8001/health  # Reasoning
curl http://localhost:8200/health  # Embeddings
```

### Verify LiteLLM Integration
```bash
curl http://motoko:8000/v1/models \
  -H "Authorization: Bearer YOUR_TOKEN"
```

### Monitor GPU Usage
```bash
docker exec vllm-reasoning-motoko nvidia-smi
```

---

## Configuration Overrides

### Change Reasoning Model
Edit `ansible/host_vars/motoko.yml`:
```yaml
vllm_reasoning_model: "google/gemma-2-2b-it-AWQ"  # Smaller model
vllm_reasoning_gpu_util: 0.30  # Lower GPU usage
```

### Adjust GPU Allocation
Edit `ansible/host_vars/motoko.yml`:
```yaml
vllm_reasoning_gpu_util: 0.50  # Increase reasoning
vllm_embeddings_gpu_util: 0.25  # Decrease embeddings
```

---

## Troubleshooting

### vLLM Container Won't Start
```bash
# Check logs
docker logs vllm-reasoning-motoko
docker logs vllm-embeddings-motoko

# Check GPU availability
nvidia-smi
docker run --rm --gpus all nvidia/cuda:12.0.0-base-ubuntu22.04 nvidia-smi
```

### Ansible Still Slow
```bash
# Check SSH ControlPersist
ls -la ~/.ansible/cp/

# Check fact cache
ls -la /tmp/ansible_facts/

# Increase forks if system can handle it
# Edit ansible.cfg: forks = 20
```

### LiteLLM Can't Reach vLLM
```bash
# Check network connectivity
docker exec litellm curl http://motoko:8001/health
docker exec litellm curl http://motoko:8200/health

# Check DNS resolution
docker exec litellm nslookup motoko
```

---

## Next Steps Checklist

- [ ] Review `docs/ARCHITECTURE_REVIEW.md`
- [ ] Test vLLM deployment
- [ ] Verify LiteLLM integration
- [ ] Monitor GPU usage
- [ ] Audit motoko-devops repository
- [ ] Begin migration (see `docs/migration/MIGRATION_PLAN.md`)

---

**See Also:**
- `docs/ARCHITECTURE_REVIEW.md` - Full architecture review
- `docs/migration/MIGRATION_PLAN.md` - Consolidation plan
- `docs/IMPLEMENTATION_SUMMARY.md` - Implementation details

