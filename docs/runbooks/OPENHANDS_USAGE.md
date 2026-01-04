# OpenHands Usage and Troubleshooting

**Service:** OpenHands AI Coding Assistant
**Gateway:** motoko.pangolin-vega.ts.net:4000 (LiteLLM)
**Owner:** Platform Engineering
**Last Updated:** 2025-12-23

---

## Overview

OpenHands is an AI coding assistant deployed across PHC workstations. It connects to the central LiteLLM gateway for LLM services, using role-based model abstraction (clients request `coder`, not specific model names).

---

## Quick Reference

| Item | Value |
|------|-------|
| **Start OpenHands** | `oh serve` |
| **With directory mount** | `oh serve --mount-cwd` |
| **With GPU** | `oh serve --gpu` |
| **Diagnostics** | `llm-doctor` |
| **Gateway URL** | `http://motoko.pangolin-vega.ts.net:4000/v1` |
| **Default Role** | `coder` |
| **Config Location** | `/etc/miket/llm/contract.json` |

---

## Available Roles

| Role | Use Case | When to Use |
|------|----------|-------------|
| `coder` | Code generation, review, editing | Default for OpenHands |
| `reasoner` | Complex multi-step reasoning | Architecture, planning |
| `encoder` | Text embeddings | RAG, search (not for chat) |
| `chat` | General conversation | Quick queries |

---

## Starting OpenHands

### Basic Start (Recommended)

```bash
oh serve
```

Opens at http://localhost:3000 with `coder` role.

### With Current Directory Mounted

```bash
oh serve --mount-cwd
```

Mounts your current working directory into the sandbox.

### With GPU Support

```bash
oh serve --gpu
```

Requires nvidia-docker or NVIDIA container toolkit.

### Different Role

```bash
oh --role reasoner serve
```

Uses `reasoner` instead of `coder`.

---

## LLM Environment Wrapper

The `llm-env` command sets up environment for any LLM-aware application:

### Print Environment

```bash
llm-env coder
# Output:
# LLM_MODEL=coder
# LLM_BASE_URL=http://motoko.pangolin-vega.ts.net:4000/v1
# LLM_API_KEY=not-required
```

### Run Command with Environment

```bash
llm-env coder -- python my_script.py
```

### Export to Current Shell

```bash
eval $(llm-env --export coder)
```

### For Specific App

```bash
llm-env --app openhands -- openhands serve
```

---

## Diagnostics

Run `llm-doctor` for comprehensive checks:

```bash
llm-doctor
```

Checks:
1. Contract file present and valid
2. DNS resolution for gateway
3. Gateway health endpoint
4. Model listing
5. Test chat completion
6. Container runtime (Docker/Podman)
7. OpenHands installation

### Quick Check

```bash
llm-doctor --quick
```

Only checks gateway connectivity.

---

## Troubleshooting

### Problem: "Gateway unreachable"

**Causes:**
1. Tailscale not connected
2. LiteLLM not running on motoko
3. Firewall blocking port 4000

**Resolution:**
```bash
# Check Tailscale
tailscale status

# Ping gateway
tailscale ping motoko

# Direct health check
curl http://motoko.pangolin-vega.ts.net:4000/health
```

### Problem: "Container runtime not found"

**Resolution (Fedora):**
```bash
sudo dnf install podman podman-docker
```

**Resolution (macOS):**
Install Docker Desktop from https://www.docker.com/products/docker-desktop/

### Problem: "openhands command not found"

**Resolution:**
```bash
# Install uv
curl -LsSf https://astral.sh/uv/install.sh | sh
source ~/.bashrc

# Install OpenHands
uv tool install openhands-ai --python 3.12
```

### Problem: Slow response times

**Causes:**
1. First request after startup (model warmup)
2. Backend (akira) under load
3. Large context requests

**Resolution:**
- Wait for warmup on first request
- Check backend: `curl http://akira.pangolin-vega.ts.net:8000/health`
- LiteLLM automatically falls back to OpenAI if local backend is busy

### Problem: OpenHands hangs on "starting runtime"

**Causes:**
1. Docker not running
2. Socket permission issues

**Resolution:**
```bash
# Check Docker/Podman
docker ps  # or: podman ps

# Start Docker Desktop (macOS)
open -a Docker

# Restart Podman (Fedora)
systemctl --user restart podman.socket
```

---

## Configuration Files

### System Configuration

| Path | Purpose |
|------|---------|
| `/etc/miket/llm/contract.json` | LLM Contract (roles, gateway URL) |
| `/etc/miket/llm/README.md` | Configuration documentation |
| `/usr/local/bin/llm-env` | Environment wrapper |
| `/usr/local/bin/oh` | OpenHands wrapper |
| `/usr/local/bin/llm-doctor` | Diagnostics script |

### User Configuration

| Path | Purpose |
|------|---------|
| `~/.openhands/config.toml` | OpenHands user config (optional) |
| `~/.local/bin/openhands` | OpenHands CLI (installed by uv) |

---

## Uninstall

### Remove Everything

```bash
# Remove wrappers
sudo rm /usr/local/bin/{llm-env,oh,llm-doctor}

# Remove contract
sudo rm -rf /etc/miket/llm/

# Remove OpenHands
uv tool uninstall openhands

# Remove user config (optional)
rm -rf ~/.openhands/
```

### Reinstall

```bash
make deploy-llm-client-canary --limit $(hostname)
```

---

## Deployment

### Canary (Recommended First)

```bash
make deploy-llm-client-canary
```

Deploys to armitage + akira only.

### Full Deployment

```bash
make deploy-llm-client
```

Deploys to all LLM client nodes.

### Validation

```bash
make validate-llm-client
```

---

## Related Documentation

- [LLM Contract](/etc/miket/llm/contract.json)
- [AI Fabric Architecture](../architecture/components/AI_FABRIC_SERVICE.md)
- [LiteLLM Operations](LITELLM_PROXY.md)
- [Discovery Notes](../notes/OPENHANDS_DISCOVERY.md)

---

## Change Log

| Date | Change | Author |
|------|--------|--------|
| 2025-12-23 | Initial runbook | Codex-CA-001 |
