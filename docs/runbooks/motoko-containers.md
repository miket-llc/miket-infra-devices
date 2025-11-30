# Motoko Container Stack Runbook

## Overview

This runbook covers deployment and management of container services on motoko:
- **vLLM** - Local AI model serving (reasoning + embeddings)
- **LiteLLM** - API gateway for LLM endpoints
- **Nextcloud** - Self-hosted file sync (optional)

All services run on **Podman** with data stored on the second internal NVMe (`/space`).

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        MOTOKO                                │
│                   Fedora 43 Server                           │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │
│  │   vLLM      │  │   vLLM      │  │  LiteLLM    │          │
│  │  Reasoning  │  │ Embeddings  │  │   Proxy     │          │
│  │  :8001      │  │   :8200     │  │   :8000     │          │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘          │
│         │                │                │                  │
│         └────────────────┴────────────────┘                  │
│                          │                                   │
│  ┌───────────────────────┴───────────────────────┐          │
│  │              Podman Runtime                    │          │
│  │         (NVIDIA Container Toolkit)             │          │
│  └───────────────────────┬───────────────────────┘          │
│                          │                                   │
│  ┌───────────────────────┴───────────────────────┐          │
│  │              /space (nvme1n1p3)               │          │
│  │     Second Internal NVMe - 951GB btrfs        │          │
│  │                                               │          │
│  │  /space/containers/engine/podman  (graphroot) │          │
│  │  /space/apps/vllm/models          (AI models) │          │
│  │  /space/apps/litellm              (config)    │          │
│  │  /space/apps/nextcloud            (data)      │          │
│  └───────────────────────────────────────────────┘          │
│                          │                                   │
│  ┌───────────────────────┴───────────────────────┐          │
│  │           NVIDIA RTX 2080 (8GB VRAM)          │          │
│  └───────────────────────────────────────────────┘          │
└─────────────────────────────────────────────────────────────┘
```

---

## Initial Deployment

### Full Stack Deployment

```bash
cd ~/dev/miket-infra-devices/ansible

# Deploy everything
ansible-playbook -i inventory/hosts.yml playbooks/motoko/containers.yml
```

### Selective Deployment

```bash
# Storage only (mount /space)
ansible-playbook -i inventory/hosts.yml playbooks/motoko/containers.yml --tags storage

# Podman runtime only
ansible-playbook -i inventory/hosts.yml playbooks/motoko/containers.yml --tags runtime

# vLLM services only
ansible-playbook -i inventory/hosts.yml playbooks/motoko/containers.yml --tags vllm

# LiteLLM only
ansible-playbook -i inventory/hosts.yml playbooks/motoko/containers.yml --tags litellm

# Nextcloud only
ansible-playbook -i inventory/hosts.yml playbooks/motoko/containers.yml --tags nextcloud
```

---

## Service Management

### Check Status

```bash
# All containers
podman ps

# Specific service logs
podman logs -f vllm-reasoning-motoko
podman logs -f vllm-embeddings-motoko
podman logs litellm

# Systemd services
systemctl status vllm-stack
systemctl status litellm
```

### Restart Services

```bash
# Via systemd
systemctl restart vllm-stack
systemctl restart litellm

# Via podman-compose
cd /space/apps/vllm && podman-compose restart
cd /space/apps/litellm && podman-compose restart
```

### Stop/Start

```bash
# Stop all AI services
systemctl stop vllm-stack litellm

# Start all AI services
systemctl start vllm-stack litellm
```

---

## Health Checks

### vLLM Services

```bash
# Reasoning model health
curl http://127.0.0.1:8001/health

# Embeddings model health  
curl http://127.0.0.1:8200/health

# List available models
curl http://127.0.0.1:8001/v1/models
curl http://127.0.0.1:8200/v1/models
```

### LiteLLM Proxy

```bash
# Health check
curl http://127.0.0.1:8000/health

# List all models (requires token)
curl -H "Authorization: Bearer $LITELLM_TOKEN" http://127.0.0.1:8000/v1/models
```

### GPU Status

```bash
# GPU utilization
nvidia-smi

# GPU memory per container
nvidia-smi --query-compute-apps=pid,name,used_memory --format=csv
```

---

## Troubleshooting

### Container Won't Start

1. Check logs:
   ```bash
   podman logs vllm-reasoning-motoko
   ```

2. Check GPU access:
   ```bash
   podman run --rm --device=nvidia.com/gpu=all docker.io/nvidia/cuda:12.3.1-base-ubuntu22.04 nvidia-smi
   ```

3. Check disk space:
   ```bash
   df -h /space
   ```

### Model Download Slow/Failing

1. Check HuggingFace cache:
   ```bash
   ls -la /space/apps/vllm/cache/
   ```

2. Manually download model:
   ```bash
   podman exec -it vllm-reasoning-motoko huggingface-cli download TheBloke/Mistral-7B-Instruct-v0.2-AWQ
   ```

### Out of GPU Memory

1. Check current allocation:
   ```bash
   nvidia-smi
   ```

2. Adjust GPU utilization in host_vars:
   ```yaml
   vllm_reasoning_gpu_util: 0.40  # Reduce from 0.45
   vllm_embeddings_gpu_util: 0.20  # Reduce from 0.25
   ```

3. Redeploy:
   ```bash
   ansible-playbook -i inventory/hosts.yml playbooks/motoko/containers.yml --tags vllm
   ```

### /space Not Mounted

1. Check fstab:
   ```bash
   cat /etc/fstab | grep space
   ```

2. Mount manually:
   ```bash
   mount /space
   ```

3. Verify:
   ```bash
   df -h /space
   ```

---

## Configuration Files

| File | Purpose |
|------|---------|
| `ansible/host_vars/motoko.yml` | All motoko-specific configuration |
| `/space/apps/vllm/docker-compose.yml` | vLLM container definitions |
| `/space/apps/litellm/docker-compose.yml` | LiteLLM container definition |
| `/space/apps/litellm/config.yaml` | LiteLLM model routing config |
| `/etc/containers/storage.conf.d/00-custom-storage.conf` | Podman graphroot config |

---

## Ports

| Service | Port | Description |
|---------|------|-------------|
| vLLM Reasoning | 8001 | Mistral 7B Instruct (OpenAI-compatible API) |
| vLLM Embeddings | 8200 | BGE Base embeddings (OpenAI-compatible API) |
| LiteLLM | 8000 | API gateway (routes to local + remote models) |
| Nextcloud | 8080 | Web UI (if enabled) |

---

## Redeployment After Changes

```bash
# After modifying host_vars/motoko.yml
ansible-playbook -i inventory/hosts.yml playbooks/motoko/containers.yml

# Force container recreation
cd /space/apps/vllm && podman-compose down && podman-compose up -d
```

---

## Backup Considerations

- **Models**: Cached in `/space/apps/vllm/cache/` - can be re-downloaded
- **LiteLLM config**: `/space/apps/litellm/config.yaml` - managed by Ansible
- **Nextcloud data**: `/space/apps/nextcloud/data/` - should be backed up

---

*Last updated: 2025-11-30*

