# LLM Client Standard

**Version:** 1.0.0
**Status:** Active
**Last Updated:** 2025-12-23

This document defines the standard for LLM client tools deployed across PHC devices.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     LLM Client Node                         │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  /etc/miket/llm/                                    │   │
│  │    ├── contract.json    (LLM Contract)              │   │
│  │    └── README.md        (Documentation)             │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  /usr/local/bin/                                    │   │
│  │    ├── llm-env          (Environment wrapper)       │   │
│  │    ├── oh               (OpenHands wrapper)         │   │
│  │    └── llm-doctor       (Diagnostics)               │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  ~/.local/bin/                                      │   │
│  │    └── openhands        (OpenHands CLI via uv)      │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                              │
                              │ Tailnet (no API key needed)
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                   LiteLLM Gateway (motoko)                  │
│                   http://motoko:4000/v1                     │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    Backend (akira)                          │
│            llama.cpp + Qwen3-Coder-30B                      │
│                 Fallback: OpenAI                            │
└─────────────────────────────────────────────────────────────┘
```

---

## Files Added by Deployment

### System Files (root-owned)

| Path | Permissions | Purpose |
|------|-------------|---------|
| `/etc/miket/llm/` | 0755 | LLM config directory |
| `/etc/miket/llm/contract.json` | 0644 | LLM Contract (roles, URLs) |
| `/etc/miket/llm/README.md` | 0644 | Documentation |
| `/usr/local/bin/llm-env` | 0755 | Environment wrapper script |
| `/usr/local/bin/oh` | 0755 | OpenHands wrapper script |
| `/usr/local/bin/llm-doctor` | 0755 | Diagnostics script |

### User Files

| Path | Owner | Purpose |
|------|-------|---------|
| `~/.local/bin/openhands` | user | OpenHands CLI (via uv) |
| `~/.openhands/config.toml` | user | Optional user config |

### Dependencies Installed

| Package | Method | On |
|---------|--------|-----|
| `jq` | dnf/apt/brew | All platforms |
| `uv` | curl install | All platforms |
| `podman` | dnf | Fedora |
| `podman-docker` | dnf | Fedora |

---

## LLM Contract Schema

The contract at `/etc/miket/llm/contract.json` follows this schema:

```json
{
  "version": "1.0.0",
  "base_url": "http://motoko.pangolin-vega.ts.net:4000/v1",
  "auth": {
    "type": "none",
    "note": "Tailnet-only access"
  },
  "roles": {
    "coder": { "description": "...", "fallback": "gpt-4o" },
    "reasoner": { "description": "...", "fallback": "gpt-4o" },
    "encoder": { "description": "...", "fallback": "text-embedding-3-small" },
    "chat": { "description": "...", "fallback": "gpt-4o-mini" }
  },
  "defaults": {
    "openhands": "coder",
    "aider": "coder",
    "obsidian": "chat"
  }
}
```

---

## Role Selection

### Per-Application Defaults

| Application | Default Role |
|-------------|--------------|
| OpenHands | `coder` |
| Claude Code | `coder` |
| aider | `coder` |
| Continue | `coder` |
| Obsidian | `chat` |
| RAG pipelines | `encoder` |

### Override Behavior

1. Command-line flag: `oh --role reasoner`
2. Environment variable: `LLM_MODEL=reasoner`
3. Contract default: Per application
4. Fallback: `chat`

---

## Environment Variables

The `llm-env` wrapper sets these variables:

| Variable | Value | Purpose |
|----------|-------|---------|
| `LLM_MODEL` | Role name (e.g., `coder`) | Model selection |
| `LLM_BASE_URL` | Gateway URL | API endpoint |
| `LLM_API_KEY` | `not-required` | Placeholder (tailnet auth) |
| `OPENAI_API_BASE` | Gateway URL | Legacy compatibility |
| `OPENAI_API_KEY` | `not-required` | Legacy compatibility |

---

## Security Model

### Authentication

- **No API keys required**: Tailscale provides network-layer authentication
- **Tailnet-only access**: Gateway only accessible from tailnet
- **No secrets stored**: `/etc/miket/llm/` contains no sensitive data

### File Permissions

- System files owned by root
- User files owned by the user
- No world-writable files
- No setuid/setgid

### Sandbox Safety

OpenHands runs in a container sandbox with:
- Default: No mounts (safe)
- `--mount-cwd`: Only current directory
- Never auto-mount `/space` (SoR protection)

---

## Verification

### Quick Health Check

```bash
llm-doctor --quick
```

### Full Validation

```bash
llm-doctor
```

### Manual Tests

```bash
# Gateway health
curl http://motoko.pangolin-vega.ts.net:4000/health

# List models
curl http://motoko.pangolin-vega.ts.net:4000/v1/models

# Test chat
curl -X POST http://motoko.pangolin-vega.ts.net:4000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model": "coder", "messages": [{"role": "user", "content": "ping"}]}'
```

---

## Uninstall

Complete removal:

```bash
# System files
sudo rm /usr/local/bin/{llm-env,oh,llm-doctor}
sudo rm -rf /etc/miket/llm/

# User files
uv tool uninstall openhands
rm -rf ~/.openhands/
```

---

## Changelog

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2025-12-23 | Initial release |
