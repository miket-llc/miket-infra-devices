# LiteLLM Proxy Deployment

This document describes the Ansible-driven deployment of LiteLLM proxy on Motoko, which provides a unified OpenAI-compatible API endpoint routing to local models (Armitage, Wintermute) and OpenAI fallback.

## Overview

The LiteLLM proxy runs on Motoko (always-on server) and routes requests to:
- **Armitage** (Qwen2.5-7B-Instruct-AWQ) → `http://armitage:8000/v1` - Default chat model
- **Wintermute** (Llama-3.1-8B-Instruct-AWQ) → `http://wintermute:8000/v1` - Reasoner fallback
- **Motoko embeddings** (BGE Base) → `http://motoko:8200/v1` - Embeddings service (placeholder)
- **OpenAI** (gpt-4o-mini or gpt-4.1-mini) - Fallback for heavy tasks or when local models are unavailable

## Architecture

- **Deployment**: Docker Compose on Motoko
- **Configuration**: `/opt/litellm/` (config files)
- **Container storage**: Uses Docker root at `/mnt/data/docker` (internal data disk)
- **Service management**: systemd unit `litellm.service`
- **Port**: 8000 (configurable)

## Prerequisites

1. **Motoko** must be accessible via Ansible (SSH)
2. **Docker** and **docker-compose-plugin** installed on Motoko
3. **Armitage** and **Wintermute** must be running their respective vLLM services
4. **OpenAI API key** for fallback routing

## Backend vLLM Services

### Armitage vLLM (Default Chat)

Armitage runs Qwen-2.5-7B-Instruct-AWQ on port 8000. This is configured as the default `local/chat` model.

### Wintermute vLLM (Reasoner)

Wintermute runs the reasoner model on port 8000. The default model is Llama-3.1-8B-Instruct-AWQ, but this can be switched to Gemma-2-9B-Instruct-AWQ by updating variables in `ansible/group_vars/motoko.yml`.

#### Wintermute vLLM Launch (Default: Llama 3.1 8B Instruct AWQ)

```bash
python -m vllm.entrypoints.openai.api_server \
  --model meta-llama/Meta-Llama-3.1-8B-Instruct-AWQ \
  --quantization awq \
  --host 0.0.0.0 --port 8000 \
  --max-model-len 8192 \
  --gpu-memory-utilization 0.90
```

#### Alternative: Gemma 2 9B Instruct AWQ

To switch to Gemma, update `ansible/group_vars/motoko.yml` and restart vLLM on Wintermute:

```bash
# Uncomment Gemma options in group_vars/motoko.yml:
# wintermute_model_display: "openai/gemma-2-9b-it-awq"
# wintermute_model_hf_id: "google/gemma-2-9b-it-AWQ"

# Then launch vLLM with Gemma:
python -m vllm.entrypoints.openai.api_server \
  --model google/gemma-2-9b-it-AWQ \
  --quantization awq \
  --host 0.0.0.0 --port 8000 \
  --max-model-len 8192 \
  --gpu-memory-utilization 0.90
```

**Note**: Armitage keeps Qwen-2.5-7B-Instruct-AWQ as-is on port 8000.

## Configuration

### Setting Secrets

**Option 1: Ansible Vault (Recommended)**

```bash
# Create/edit vault file
ansible-vault create ansible/group_vars/motoko.yml

# Or edit existing vault
ansible-vault edit ansible/group_vars/motoko.yml
```

Add these variables:
```yaml
openai_api_key: "sk-your-actual-openai-key"
litellm_bearer_token: "mkt-your-super-long-bearer-token"
```

**Option 2: Override at Runtime**

```bash
ansible-playbook -i ansible/inventories/hosts.ini \
  ansible/deploy-litellm.yml \
  -e "openai_api_key=sk-xxx" \
  -e "litellm_bearer_token=mkt-xxx"
```

**Option 3: Environment Variables**

```bash
export OPENAI_API_KEY="sk-xxx"
export LITELLM_TOKEN="mkt-xxx"
ansible-playbook -i ansible/inventories/hosts.ini \
  ansible/deploy-litellm.yml \
  -e "openai_api_key=${OPENAI_API_KEY}" \
  -e "litellm_bearer_token=${LITELLM_TOKEN}"
```

### Customizing Configuration

Edit `ansible/group_vars/motoko.yml` to override defaults:

```yaml
# Change port
litellm_port: 8001

# Change backend URLs
armitage_base_url: "http://armitage:8001/v1"

# Adjust budget
openai_budget_monthly_usd: 200

# Change models
openai_strong_model: "gpt-4-turbo"
openai_cheap_model: "gpt-3.5-turbo"
```

## Deployment

### Initial Deployment

```bash
cd ansible
ansible-playbook -i inventories/hosts.ini deploy-litellm.yml
```

### With Vault Password

```bash
# Using vault password file
ansible-playbook -i inventories/hosts.ini deploy-litellm.yml \
  --vault-password-file ~/.ansible/vault_pass.txt

# Or prompt for vault password
ansible-playbook -i inventories/hosts.ini deploy-litellm.yml --ask-vault-pass
```

### Updating Configuration

Simply re-run the playbook - it's idempotent:

```bash
ansible-playbook -i inventories/hosts.ini deploy-litellm.yml
```

The playbook will:
1. Update configuration files if changed
2. Restart the service automatically
3. Pull latest Docker image if version changed

## Verification

### Check Service Status

```bash
# On Motoko
systemctl status litellm
docker ps | grep litellm
```

### Test API Endpoint

```bash
# List available models
curl -H "Authorization: Bearer mkt-REPLACE_ME_SUPERLONG" \
     http://motoko:8000/v1/models

# Expected response includes:
# - local/chat
# - local/reasoner
# - local/embed
# - openai/strong
# - openai/cheap
```

### Test Chat Completion

```bash
curl -X POST http://motoko:8000/v1/chat/completions \
  -H "Authorization: Bearer mkt-REPLACE_ME_SUPERLONG" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "local/chat",
    "messages": [{"role": "user", "content": "Hello!"}]
  }'
```

### Test Health Endpoint

```bash
curl http://motoko:8000/health
```

## Routing Policy

### Default Behavior

- **Chat completions** (`/v1/chat/completions`): Routes to `local/chat` (Armitage)
- **Embeddings** (`/v1/embeddings`): Routes to `local/embed` (Motoko placeholder)

### Fallback Chain

For chat completions:
1. `local/chat` (Armitage - Qwen2.5-7B)
2. `local/reasoner` (Wintermute - Mistral-7B) - if Armitage fails
3. `openai/strong` (gpt-4.1-mini) - if both local models fail

### Automatic Routing Rules

1. **Token limit**: If input tokens > 12,000 → routes to `openai/strong`
2. **Health check failures**: After 3 consecutive failures → routes to `openai/strong`
3. **Budget exceeded**: If monthly OpenAI spend > $150 → routes to `local/chat`

## Client Configuration

### Obsidian

1. **Base URL**: `http://motoko:8000/v1`
2. **Model**: `local/chat` (default) or `openai/strong` (for heavy tasks)
3. **API Key**: Use your `litellm_bearer_token` value
4. **Headers**: `Authorization: Bearer mkt-REPLACE_ME_SUPERLONG`

**For Embeddings Plugins:**
- Base URL: `http://motoko:8000/v1`
- Model: `local/embed`
- Same Bearer token

### Python Scripts

```python
import openai

client = openai.OpenAI(
    base_url="http://motoko:8000/v1",
    api_key="mkt-REPLACE_ME_SUPERLONG"
)

response = client.chat.completions.create(
    model="local/chat",
    messages=[{"role": "user", "content": "Hello!"}]
)
```

### Trailblazer

Configure Trailblazer to use:
- **Endpoint**: `http://motoko:8000/v1`
- **Model**: `local/chat` or `openai/strong`
- **Auth**: Bearer token authentication

## Security Considerations

### Network Access

The proxy binds to `0.0.0.0:8000` by default, making it accessible on the local network. Consider:

1. **Tailscale**: Access via Tailscale VPN (recommended)
   - Use `motoko.pangolin-vega.ts.net:8000` instead of local IP
   - Already configured in your Tailnet

2. **Cloudflare Access**: Gate behind Cloudflare Access for web-based clients
   - Configure Cloudflare Tunnel on Motoko
   - Add access policy for `/v1/*` endpoints

3. **Firewall**: Restrict access via UFW/firewalld
   ```bash
   # Allow only Tailscale network
   sudo ufw allow from 100.64.0.0/10 to any port 8000
   ```

### Authentication

- **Bearer token**: Required for all requests
- **Token rotation**: Update `litellm_bearer_token` in vault and redeploy
- **Key management**: Store tokens in Ansible Vault, never commit plaintext

## Troubleshooting

### Service Won't Start

```bash
# Check logs
journalctl -u litellm -n 50
docker logs litellm

# Check Docker Compose
cd /opt/litellm
docker compose ps
docker compose logs
```

### Models Not Available

```bash
# Verify backend services are running
curl http://armitage:8000/health
curl http://wintermute:8000/health

# Check network connectivity from Motoko
docker exec litellm ping -c 3 armitage
docker exec litellm ping -c 3 wintermute
```

### Configuration Issues

```bash
# Validate config file
cat /opt/litellm/litellm.config.yaml

# Check environment variables
cat /opt/litellm/.env

# Test config syntax
docker run --rm -v /opt/litellm/litellm.config.yaml:/config.yaml \
  ghcr.io/berriai/litellm:v1.43.0 \
  litellm --config /config.yaml --test
```

### Budget Exceeded

When budget is exceeded, all requests route to `local/chat`. To reset:

1. Update budget in `ansible/group_vars/motoko.yml`
2. Redeploy: `ansible-playbook -i inventories/hosts.ini deploy-litellm.yml`
3. Or manually edit `/opt/litellm/litellm.config.yaml` and restart service

## Maintenance

### Updating LiteLLM Version

Edit `ansible/group_vars/motoko.yml`:
```yaml
litellm_version: "v1.44.0"  # Update to latest
```

Then redeploy:
```bash
ansible-playbook -i inventories/hosts.ini deploy-litellm.yml
```

### Viewing Logs

```bash
# Systemd logs
journalctl -u litellm -f

# Docker logs
docker logs -f litellm

# Docker Compose logs
cd /opt/litellm && docker compose logs -f
```

### Restarting Service

```bash
# Via systemd
sudo systemctl restart litellm

# Via Docker Compose
cd /opt/litellm && docker compose restart

# Via Ansible
ansible-playbook -i inventories/hosts.ini deploy-litellm.yml
```

## File Structure

```
ansible/
├── inventories/
│   └── hosts.ini              # Inventory file
├── group_vars/
│   └── motoko.yml             # Motoko-specific variables (secrets here)
├── roles/
│   └── litellm_proxy/
│       ├── defaults/
│       │   └── main.yml       # Role defaults
│       ├── tasks/
│       │   └── main.yml       # Deployment tasks
│       ├── handlers/
│       │   └── main.yml       # Service restart handlers
│       └── templates/
│           ├── litellm.config.yaml.j2    # LiteLLM config template
│           ├── docker-compose.yml.j2     # Docker Compose template
│           ├── litellm.env.j2            # Environment variables template
│           └── litellm.service.j2        # systemd unit template
└── deploy-litellm.yml         # Main deployment playbook
```

## Variables Reference

See `ansible/group_vars/motoko.yml` for all configurable variables. Key variables:

- `litellm_version`: Docker image tag (default: `v1.43.0`)
- `litellm_port`: Service port (default: `8000`)
- `armitage_base_url`: Armitage vLLM endpoint
- `wintermute_base_url`: Wintermute vLLM endpoint
- `openai_api_key`: OpenAI API key (REQUIRED - set via vault)
- `litellm_bearer_token`: Bearer token for auth (REQUIRED - set via vault)
- `openai_budget_monthly_usd`: Monthly spend limit (default: `150`)

## Support

For issues or questions:
1. Check logs: `journalctl -u litellm` or `docker logs litellm`
2. Verify backend services are running
3. Review configuration files in `/opt/litellm/`
4. Check Ansible playbook output for errors

