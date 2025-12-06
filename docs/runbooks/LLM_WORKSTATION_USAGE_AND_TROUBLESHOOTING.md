# LLM Workstation Usage and Troubleshooting

**Last Updated:** 2025-12-06  
**Scope:** Using and troubleshooting Ollama LLM on workstation nodes (e.g., armitage).

## Architecture Context

Per ADR-005 and the AI Fabric Platform Contract:
- **Workstations** (armitage) use the **Ollama** pattern - lightweight, single-user focused
- **Servers** (akira) use the **vLLM** pattern - high-throughput, multi-user server

This runbook covers the Ollama workstation pattern.

## Filesystem Layout (Flux/Space/Time)

```
/flux/apps/ollama/              # Binary, config, scripts
├── bin/
│   └── ollama-health.sh        # Health check script
└── config/                     # Configuration files

/space/llm/ollama/              # Large data (model weights)
├── models/                     # Downloaded model files (multi-GB each)
└── data/                       # Runtime data

/flux/runtime/secrets/          # Environment files from AKV
└── ai-fabric.env               # API keys for upstream services
```

## Endpoints and Ports

| Port  | Service          | Description                     |
|-------|------------------|---------------------------------|
| 11434 | Ollama API       | Primary LLM inference endpoint  |
| 8000  | LLM Gateway      | Optional proxy (LiteLLM, etc.)  |

Both ports are accessible only via tailnet (firewall enforced).

## Common Operations

### Check Service Status

```bash
# Ollama service status
sudo systemctl status ollama

# View logs
sudo journalctl -u ollama -f

# Health check script
/flux/apps/ollama/bin/ollama-health.sh
```

### Test Ollama API

```bash
# List installed models
curl http://localhost:11434/api/tags

# Simple generation test
curl http://localhost:11434/api/generate -d '{
  "model": "qwen2.5:7b",
  "prompt": "Explain quantum computing in one sentence.",
  "stream": false
}'

# Chat completion format (OpenAI compatible)
curl http://localhost:11434/v1/chat/completions -d '{
  "model": "qwen2.5:7b",
  "messages": [{"role": "user", "content": "Hello!"}]
}'
```

### Test from Tailnet

From another device on the tailnet:

```bash
# Test Ollama API
curl http://armitage.pangolin-vega.ts.net:11434/api/tags

# Test generation
curl http://armitage.pangolin-vega.ts.net:11434/api/generate -d '{
  "model": "qwen2.5:7b",
  "prompt": "Hello from the network!",
  "stream": false
}'
```

### Manage Models

```bash
# List models
ollama list

# Pull a new model
ollama pull llama3.2:3b

# Remove a model
ollama rm llama3.2:3b

# Show model info
ollama show qwen2.5:7b

# Run interactive chat
ollama run qwen2.5:7b
```

### Restart Services

```bash
# Restart Ollama
sudo systemctl restart ollama

# Reload systemd if service file changed
sudo systemctl daemon-reload

# Check status after restart
sudo systemctl status ollama
```

## GPU Monitoring

### NVIDIA GPU (armitage)

```bash
# Real-time GPU monitoring
nvidia-smi

# Watch mode (updates every 1 second)
watch -n 1 nvidia-smi

# GPU process list
nvidia-smi --query-compute-apps=pid,process_name,used_memory --format=csv

# Check CUDA availability
ollama run qwen2.5:7b "What GPU are you using?"
# Should mention CUDA or GPU acceleration
```

## Troubleshooting

### Problem: Ollama Service Not Starting

**Symptoms:** `systemctl status ollama` shows failed

**Diagnosis:**
```bash
# Check detailed logs
sudo journalctl -u ollama -n 50

# Common causes:
# 1. GPU driver issues
# 2. Port already in use
# 3. Permission problems
```

**Solutions:**

1. **GPU Driver Issues:**
   ```bash
   # Check NVIDIA driver
   nvidia-smi
   
   # If driver not found, reinstall:
   sudo dnf install akmod-nvidia
   sudo systemctl reboot
   ```

2. **Port in Use:**
   ```bash
   # Check what's using port 11434
   sudo ss -tlnp | grep 11434
   
   # Kill conflicting process or change Ollama port
   ```

3. **Permission Issues:**
   ```bash
   # Verify ollama user/group
   id ollama
   
   # Fix ownership
   sudo chown -R ollama:ollama /flux/apps/ollama
   sudo chown -R ollama:ollama /space/llm/ollama
   ```

### Problem: No GPU Acceleration

**Symptoms:** Inference is very slow, nvidia-smi shows no Ollama process

**Diagnosis:**
```bash
# Check if GPU is detected
ollama run qwen2.5:7b "Are you using GPU acceleration?"

# Check Ollama logs for GPU detection
sudo journalctl -u ollama | grep -i gpu
```

**Solutions:**

1. **Verify CUDA Installation:**
   ```bash
   # Check CUDA toolkit
   nvcc --version
   
   # Check NVIDIA driver
   nvidia-smi
   ```

2. **Set GPU Environment:**
   ```bash
   # Verify in /etc/ollama.env
   cat /etc/ollama.env | grep CUDA
   
   # Should contain:
   # CUDA_VISIBLE_DEVICES=all
   ```

3. **Restart with Debug:**
   ```bash
   sudo systemctl stop ollama
   OLLAMA_DEBUG=1 ollama serve
   # Look for GPU detection messages
   ```

### Problem: Model Download Fails

**Symptoms:** `ollama pull` hangs or fails

**Diagnosis:**
```bash
# Check disk space
df -h /space

# Check network
ping registry.ollama.ai
```

**Solutions:**

1. **Disk Space:**
   ```bash
   # Models can be 4-10+ GB each
   # Clean up old models
   ollama rm <old-model>
   ```

2. **Network Issues:**
   ```bash
   # Use explicit timeout
   timeout 3600 ollama pull qwen2.5:7b
   ```

### Problem: Firewall Blocking Access

**Symptoms:** Can't reach Ollama from other tailnet devices

**Diagnosis:**
```bash
# Check firewall rules
sudo firewall-cmd --zone=tailnet --list-all

# Check if port is open
sudo ss -tlnp | grep 11434

# Test local access
curl http://localhost:11434/api/tags
```

**Solutions:**

1. **Add Firewall Rule:**
   ```bash
   # Add Ollama port to tailnet zone
   sudo firewall-cmd --zone=tailnet --add-port=11434/tcp --permanent
   sudo firewall-cmd --reload
   ```

2. **Verify Binding:**
   ```bash
   # Ollama must bind to 0.0.0.0, not 127.0.0.1
   # Check /etc/ollama.env:
   # OLLAMA_HOST=0.0.0.0:11434
   ```

### Problem: Missing Secret/API Key

**Symptoms:** LLM gateway returns authentication errors

**Diagnosis:**
```bash
# Check if secrets are synced
ls -la /flux/runtime/secrets/

# Verify env file exists
cat /flux/runtime/secrets/ai-fabric.env
```

**Solutions:**

1. **Run Secrets Sync:**
   ```bash
   # From motoko
   ansible-playbook -i ansible/inventory/hosts.yml \
     ansible/playbooks/secrets-sync.yml \
     --limit armitage
   ```

2. **Verify AKV Access:**
   ```bash
   # On armitage
   az account show
   az keyvault secret list --vault-name kv-miket-ops
   ```

### Problem: Out of Memory (OOM)

**Symptoms:** Ollama crashes during inference, especially with large context

**Diagnosis:**
```bash
# Check system memory
free -h

# Check GPU memory
nvidia-smi

# Check OOM in logs
sudo journalctl -u ollama | grep -i "out of memory\|oom"
```

**Solutions:**

1. **Reduce Context Size:**
   ```bash
   # Use smaller num_ctx in requests
   curl http://localhost:11434/api/generate -d '{
     "model": "qwen2.5:7b",
     "prompt": "...",
     "options": {"num_ctx": 4096}
   }'
   ```

2. **Use Smaller Model:**
   ```bash
   # Try 3B instead of 7B
   ollama run llama3.2:3b
   ```

3. **Adjust GPU Memory Utilization:**
   ```bash
   # Edit /etc/ollama.env and reduce
   # GPU_MEMORY_UTILIZATION=0.80
   sudo systemctl restart ollama
   ```

## Performance Tips

1. **Pre-load Models:** Keep frequently used models warm
   ```bash
   # Load model into memory
   curl http://localhost:11434/api/generate -d '{"model": "qwen2.5:7b", "keep_alive": "24h"}'
   ```

2. **Use Appropriate Context Size:** Smaller context = faster inference

3. **Monitor GPU Temperature:**
   ```bash
   # Thermal throttling reduces performance
   watch -n 2 'nvidia-smi --query-gpu=temperature.gpu --format=csv'
   ```

## Related Runbooks

- [Armitage Rebuild Guide](./ARMITAGE_REBUILD_FEDORA_KDE_OLLAMA.md)
- [AI Fabric Runtime](./AI_FABRIC_RUNTIME.md)
- [Device Health Check](./device-health-check.md)
- [Tailscale Device Setup](./TAILSCALE_DEVICE_SETUP.md)

