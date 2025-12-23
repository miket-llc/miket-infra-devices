# LiteLLM Proxy Runbook

This runbook covers the LiteLLM proxy deployment on Akira, which provides a stable OpenAI-compatible endpoint for CLI tooling (ask-cli) routing to vLLM backends on the tailnet.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         TAILNET                                  │
│                                                                  │
│   ┌──────────────┐      ┌──────────────┐      ┌──────────────┐  │
│   │  count-zero  │      │   motoko     │      │   armitage   │  │
│   │   (macOS)    │      │   (Fedora)   │      │   (Fedora)   │  │
│   │              │      │              │      │              │  │
│   │  ask-cli ────┼──────┼──────────────┼──────┼──────────────┼──┤
│   └──────────────┘      └──────────────┘      └──────────────┘  │
│          │                     │                     │          │
│          │                     │                     │          │
│          ▼                     ▼                     ▼          │
│   ┌──────────────────────────────────────────────────────────┐  │
│   │                      AKIRA                                │  │
│   │  ┌────────────────────────────────────────────────────┐  │  │
│   │  │                LiteLLM Proxy                        │  │  │
│   │  │                   :4000                             │  │  │
│   │  │  /v1/chat/completions  /v1/models  /health         │  │  │
│   │  └────────────────────────────────────────────────────┘  │  │
│   │                          │                                │  │
│   │                          ▼                                │  │
│   │  ┌────────────────────────────────────────────────────┐  │  │
│   │  │                  vLLM Backend                       │  │  │
│   │  │                    :8000                            │  │  │
│   │  │              qwen2.5-7b (ROCm)                      │  │  │
│   │  └────────────────────────────────────────────────────┘  │  │
│   └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

## Endpoints

| Endpoint | URL | Purpose |
|----------|-----|---------|
| LiteLLM Proxy | `http://akira.pangolin-vega.ts.net:4000/v1` | OpenAI-compatible API |
| Models List | `http://akira:4000/v1/models` | Available models |
| Health Check | `http://akira:4000/health` | Service health |
| vLLM Backend | `http://akira:8000/v1` | Direct vLLM (not for clients) |

## Available Models

| Model Alias | Backend | Description |
|-------------|---------|-------------|
| `akira/qwen2.5-7b` | akira:8000 | Primary chat model (32K context) |
| `default` | akira:8000 | Alias for primary model |

## Deployment

### Prerequisites

1. **vLLM must be running on akira:8000**
   ```bash
   curl http://akira:8000/health
   curl http://akira:8000/v1/models
   ```

2. **Secrets synced (optional)**
   ```bash
   # Provision litellm-master-key in Azure Key Vault first
   ansible-playbook -i inventory/hosts.yml playbooks/secrets-sync.yml --limit akira
   ```

### Deploy LiteLLM

```bash
# Full deployment
make deploy-litellm

# Or directly via Ansible
cd ansible
ansible-playbook -i inventory/hosts.yml playbooks/akira/deploy-litellm.yml
```

### Validate Deployment

```bash
# Automated validation
make validate-litellm

# Manual checks
curl http://akira:4000/health
curl http://akira:4000/v1/models | jq '.data[].id'
```

### Deploy ask-cli

```bash
# Deploy to all Linux hosts
make deploy-ask-cli

# Or limit to specific hosts
cd ansible
ansible-playbook -i inventory/hosts.yml playbooks/deploy-ask-cli.yml --limit motoko
```

## Client Configuration

### Environment Variables

```bash
export ASK_BASE_URL=http://akira.pangolin-vega.ts.net:4000
export ASK_MODEL=default
# Optional: API key if LITELLM_MASTER_KEY is set
export ASK_API_KEY=your-key-here
```

### Using ask-cli

```bash
# Basic query
ask "What is the capital of France?"

# Specific model
ask -m akira/qwen2.5-7b "Explain quantum computing"

# List available models
ask --list-models

# With system prompt
ask -s "You are a helpful coding assistant" "Write a Python function to sort a list"

# Pipe input
echo "Explain this code" | ask
cat script.py | ask "Review this code for bugs"
```

### Python Client

```python
import openai

client = openai.OpenAI(
    base_url="http://akira.pangolin-vega.ts.net:4000/v1",
    api_key="not-needed"  # or your LITELLM_MASTER_KEY
)

response = client.chat.completions.create(
    model="akira/qwen2.5-7b",
    messages=[{"role": "user", "content": "Hello!"}]
)
print(response.choices[0].message.content)
```

## Operations

### Service Management

```bash
# On akira
sudo systemctl status litellm
sudo systemctl restart litellm
sudo systemctl stop litellm

# View logs
sudo journalctl -u litellm -f

# Container logs
sudo podman logs -f litellm
```

### Configuration Files

| File | Purpose |
|------|---------|
| `/flux/apps/litellm/config.yaml` | LiteLLM routing configuration |
| `/flux/apps/litellm/.env` | Environment variables (secrets) |
| `/flux/apps/litellm/docker-compose.yml` | Container definition |
| `/etc/systemd/system/litellm.service` | Systemd unit |

### Update Configuration

```bash
# Edit config
sudo vim /flux/apps/litellm/config.yaml

# Restart to apply
sudo systemctl restart litellm
```

## Troubleshooting

### LiteLLM Not Starting

```bash
# Check service status
sudo systemctl status litellm

# Check container
sudo podman ps -a | grep litellm

# View logs
sudo journalctl -u litellm -n 100

# Check port binding
ss -tlnp | grep 4000
```

### vLLM Backend Unreachable

```bash
# Check vLLM health
curl http://127.0.0.1:8000/health

# Check vLLM service
sudo systemctl status vllm  # if using systemd
sudo podman ps | grep vllm  # if containerized

# Test from LiteLLM container
sudo podman exec litellm curl http://127.0.0.1:8000/health
```

### DNS Resolution Issues

```bash
# Use IP instead of hostname for local backend
# Edit /flux/apps/litellm/config.yaml:
#   api_base: "http://127.0.0.1:8000/v1"  # Not akira.pangolin-vega.ts.net
```

### Firewall Issues

```bash
# Check firewall rules
sudo firewall-cmd --list-all

# Verify tailnet access
sudo firewall-cmd --list-rich-rules | grep 100.64

# Re-add rule if missing
sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="100.64.0.0/10" port port="4000" protocol="tcp" accept'
sudo firewall-cmd --reload
```

### Model Not Found

```bash
# List available models
curl http://akira:4000/v1/models | jq '.data[].id'

# Check vLLM models
curl http://akira:8000/v1/models | jq '.data[].id'

# Verify model alias in config
cat /flux/apps/litellm/config.yaml | grep model_name
```

### Bad Model Alias

If clients get "model not found" errors:

1. Check the config has the model alias:
   ```bash
   cat /flux/apps/litellm/config.yaml | grep -A5 "model_name"
   ```

2. Restart LiteLLM to reload config:
   ```bash
   sudo systemctl restart litellm
   ```

3. Verify the model is listed:
   ```bash
   curl http://akira:4000/v1/models | jq '.data[].id'
   ```

### Connection Refused from Other Hosts

1. Check LiteLLM is binding to all interfaces:
   ```bash
   ss -tlnp | grep 4000
   # Should show 0.0.0.0:4000 or *:4000
   ```

2. Check firewall allows tailnet:
   ```bash
   sudo firewall-cmd --list-rich-rules
   ```

3. Verify tailscale connectivity:
   ```bash
   tailscale ping akira
   ```

## Adding New Models/Backends

### Add a New vLLM Backend

1. Edit the playbook vars or create host_vars:
   ```yaml
   # ansible/host_vars/akira.yml (or in playbook vars)
   vllm_backends:
     - name: "akira-local"
       host: "127.0.0.1"
       port: 8000
       models:
         - id: "qwen2.5-7b"
           alias: "akira/qwen2.5-7b"
           max_model_len: 32768
         - id: "llama3-8b"  # New model
           alias: "akira/llama3-8b"
           max_model_len: 8192
   ```

2. Redeploy:
   ```bash
   make deploy-litellm
   ```

### Add Remote Backend (Future)

```yaml
vllm_backends:
  - name: "akira-local"
    host: "127.0.0.1"
    port: 8000
    models:
      - id: "qwen2.5-7b"
        alias: "akira/qwen2.5-7b"
  - name: "wintermute"
    host: "wintermute.pangolin-vega.ts.net"
    port: 8000
    models:
      - id: "llama3-70b"
        alias: "wintermute/llama3-70b"
```

## Security

### Network Access

- LiteLLM binds to all interfaces (`0.0.0.0:4000`)
- Firewall restricts access to tailnet only (`100.64.0.0/10`)
- No public internet exposure

### Authentication (Optional)

To enable API key authentication:

1. Set `LITELLM_MASTER_KEY` in Azure Key Vault
2. Sync secrets: `ansible-playbook playbooks/secrets-sync.yml --limit akira`
3. Clients must include: `Authorization: Bearer <key>`

### Secrets

- Secrets stored in Azure Key Vault (`kv-miket-ops`)
- Synced to `/flux/apps/litellm/.env` with mode 0600
- Never committed to git

## Related Documentation

- [AI Fabric Platform Contract](../architecture/AI_FABRIC_SERVICE.md)
- [ADR-005: LLM Runtime Pattern](../architecture/ADR-005.md)
- [Secrets Management](../architecture/SECRETS.md)
