# OpenHands LLM Client Discovery

**Date:** 2025-12-23
**Author:** Chief Device Architect (Codex-CA-001)
**Status:** Discovery Complete

## Executive Summary

This document captures the discovery phase for deploying OpenHands across the PHC device fleet, integrated with the LiteLLM AI Fabric gateway.

## Team 1 Handoff Summary

**From:** miket-infra (LiteLLM Control Plane)

| Item | Value |
|------|-------|
| **LiteLLM Base URL** | `http://motoko.pangolin-vega.ts.net:4000/v1` |
| **Auth** | None (tailnet provides network-layer security) |
| **Contract File** | `docs/reference/llm-contract.json` (in miket-infra) |
| **Primary Backend** | akira (Qwen3-Coder-30B via llama.cpp) |
| **Fallback** | OpenAI gpt-4o |

### Role Names

| Role | Purpose | Default For |
|------|---------|-------------|
| `coder` | Code generation, review | OpenHands, Claude Code, aider |
| `reasoner` | Complex reasoning | Research, planning |
| `encoder` | Embeddings | RAG, search |
| `chat` | General conversation | Chatbots, quick queries |

## Existing Infrastructure Analysis

### Reusable Roles

| Role | Purpose | Can Reuse? |
|------|---------|------------|
| `secrets_sync` | AKV → local env files | Yes, but NOT NEEDED (no secrets required) |
| `litellm_proxy` | LiteLLM server deployment | Reference for container patterns |
| `codex_cli` | CLI tool distribution | Reference for OS dispatch pattern |

### Key Insight: No Secrets Required

The LiteLLM gateway uses **tailnet-only access** with no API key authentication. This simplifies the deployment significantly:
- No secrets to sync from AKV
- No env files with credentials
- Network-layer security via Tailscale

### Target Groups

| Group | Hosts | OpenHands Mode |
|-------|-------|----------------|
| `linux_workstations` | akira, armitage, atom | GUI (serve) |
| `container_hosts` | motoko, akira, armitage, wintermute | Docker available |

**Note:** wintermute (Windows) deferred to WSL2 strategy for initial rollout.

## OpenHands Configuration Findings

### Installation Methods

1. **uvx (Recommended):** `uvx --python 3.12 --from openhands-ai openhands serve`
2. **pip:** `pip install openhands` then `openhands serve`
3. **Docker:** Direct docker run (complex, requires socket mount)

### LLM Configuration

OpenHands reads LLM settings from:
1. Environment variables: `LLM_MODEL`, `LLM_API_KEY`, `LLM_BASE_URL`
2. Config file: `~/.openhands/config.toml` or project-level `config.toml`
3. Web UI settings (overrides env vars)

**Key config.toml options:**
```toml
[llm]
model = "coder"
base_url = "http://motoko.pangolin-vega.ts.net:4000/v1"
api_key = "not-required"  # Tailnet auth
```

### Runtime Requirements

- Docker Desktop or Podman (for sandbox)
- Python 3.12+
- uv package manager (recommended)
- 4GB+ RAM

## Design Decisions

### D1: Single Config Directory

**Location:** `/etc/miket/llm/`

**Contents:**
- `contract.json` - LLM Contract (verbatim from Team 1)
- `README.md` - What this is and how to remove it

**Rationale:** Minimal footprint, discoverable, auditable.

### D2: No Secrets in /etc

The tailnet provides authentication. No API keys needed for LiteLLM gateway access.

### D3: LLM Environment Wrapper

**Location:** `/usr/local/bin/llm-env`

**Purpose:** Single utility that:
1. Reads the contract
2. Selects a role (default or specified)
3. Outputs env vars or execs a command with the correct environment

**Usage:**
```bash
# Print environment
llm-env coder

# Run command with environment
llm-env coder -- some-command

# Use default role for app
llm-env --app openhands -- openhands serve
```

### D4: OpenHands Wrapper

**Location:** `/usr/local/bin/oh`

**Purpose:** Thin wrapper that:
1. Calls llm-env with default role `coder`
2. Passes through to openhands serve
3. Supports role override

**Usage:**
```bash
# Default (coder role)
oh serve

# With role override
oh --role reasoner serve

# With GPU
oh serve --gpu

# Mount current directory
oh serve --mount-cwd
```

### D5: Container Runtime

OpenHands requires Docker/Podman for sandboxing. Use existing `container_hosts` group.

**Safe Mount Policy:**
- Default: mount only current directory (`--mount-cwd`)
- Never auto-mount `/space` (SoR protection)
- User can explicitly add mounts if needed

### D6: Rollout Strategy

**Phase 1 (Canary):**
- armitage (workstation with Ollama)
- akira (server with vLLM - already has LLM)

**Phase 2:**
- atom (basecamp node)
- count-zero (macOS)

**Phase 3:**
- wintermute (Windows via WSL2 - deferred)

## Ansible Role Design

### Role: `llm_contract_client`

Distributes the LLM contract to clients.

**Tasks:**
1. Create `/etc/miket/llm/` directory
2. Copy `contract.json` from miket-infra
3. Create `README.md` explaining the setup

### Role: `llm_client_tools`

Installs the wrapper scripts.

**Tasks:**
1. Install `llm-env` script
2. Install `oh` wrapper script
3. Ensure jq is available (for JSON parsing)

### Role: `openhands`

Installs OpenHands.

**Tasks:**
1. Ensure uv is installed
2. Install openhands via uv tool
3. Verify Docker/Podman is available
4. Create user-level config if needed

## Doctor Checks

A single validation command that verifies:
1. Contract file present and valid JSON
2. LiteLLM gateway reachable
3. Role `coder` returns valid response
4. Docker/Podman runtime available
5. openhands command available

**Implementation:** `llm-doctor` script or ansible playbook with `--tags validate`

## Files Added by This Deployment

| Path | Purpose | Permissions |
|------|---------|-------------|
| `/etc/miket/llm/contract.json` | LLM Contract | 0644 |
| `/etc/miket/llm/README.md` | Documentation | 0644 |
| `/usr/local/bin/llm-env` | Environment wrapper | 0755 |
| `/usr/local/bin/oh` | OpenHands wrapper | 0755 |
| `/usr/local/bin/llm-doctor` | Validation script | 0755 |
| `~/.local/bin/openhands` | OpenHands CLI (via uv) | user |

## Uninstall/Rollback

```bash
# Remove wrappers
sudo rm /usr/local/bin/{llm-env,oh,llm-doctor}

# Remove contract
sudo rm -rf /etc/miket/llm/

# Remove OpenHands
uv tool uninstall openhands
```

## Open Questions

1. **macOS:** Should we use Homebrew or uv for installation?
2. **Windows:** WSL2 only or native support later?
3. **GPU:** Should `oh` default to `--gpu` on gpu_nodes?

## References

- [OpenHands Local Setup](https://docs.openhands.dev/openhands/usage/run-openhands/local-setup)
- [OpenHands LLM Backends](https://docs.openhands.dev/modules/usage/llms)
- [LiteLLM Handoff](../../../miket-infra/docs/handoffs/LITELLM_HANDOFF_TO_DEVICES.md)
- [LLM Contract](../../../miket-infra/docs/reference/llm-contract.json)
