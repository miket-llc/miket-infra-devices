# AI Client Access Profiles

This runbook standardizes how Obsidian, Trailblazer, and CLI users connect to the AI endpoint on the tailnet and keep API keys out of local state.

## Authentication model (Tailscale + Vault)
1. **Network boundary:** All clients must reach the service over Tailscale using the private endpoint `https://ai.miket.tail:8000`. No direct internet access is permitted.
2. **Credential source:** The API key is stored in Vault (KV) as `ai/proxy/api-key`. Fetch it just-in-time and export it to the shell that launches your client:
   ```bash
   export AI_PROXY_API_KEY="$(vault kv get -field=token ai/proxy/api-key)"
   ```
3. **Never persist locally:** Do not commit keys, and avoid storing them in global config. Use per-client `.env` or `config.json` kept alongside the app configuration.

### Client examples
- **Obsidian** (`.env.obsidian` consumed by the OpenAI-compatible plugin):
  ```env
  OPENAI_API_KEY=${AI_PROXY_API_KEY}
  OPENAI_BASE_URL=https://ai.miket.tail:8000/v1
  MODEL=gpt-4.1-mini
  ```
  Point the plugin to `OPENAI_BASE_URL`, select `MODEL`, and reload Obsidian to pick up the environment file.

- **Trailblazer** (`trailblazer.config.json` in the app directory):
  ```json
  {
    "apiBase": "https://ai.miket.tail:8000/v1",
    "apiKey": "${AI_PROXY_API_KEY}",
    "defaultModel": "gpt-4.1-mini",
    "timeoutMs": 20000
  }
  ```
  Trailblazer reads this file at startup; restart after updating the key.

- **CLI** (`.env.ai-cli` for curl, httpie, or litellm wrappers):
  ```env
  OPENAI_API_KEY=${AI_PROXY_API_KEY}
  OPENAI_API_BASE=https://ai.miket.tail:8000/v1
  OPENAI_MODEL=gpt-4.1-mini
  ```
  Source the file before running commands:
  ```bash
  source .env.ai-cli
  curl -sS -H "Authorization: Bearer $OPENAI_API_KEY" \
    -H "Content-Type: application/json" \
    -d '{"model":"'$OPENAI_MODEL'","messages":[{"role":"user","content":"ping"}]}' \
    "$OPENAI_API_BASE/chat/completions"
  ```

## Per-device profile examples (standard endpoint: ai.miket.tail:8000)
- **macOS (Homebrew/launchctl friendly):** Store a local profile at `~/.config/miket/ai-profile.json`:
  ```json
  {
    "base_url": "https://ai.miket.tail:8000/v1",
    "api_key_env": "AI_PROXY_API_KEY",
    "model": "gpt-4.1-mini"
  }
  ```
  Export `AI_PROXY_API_KEY` in `~/.zshrc` or a direnv-managed `.envrc` so GUI apps inherit it.

- **Windows:** Place a profile at `%APPDATA%\Miket\ai-profile.json`:
  ```json
  {
    "base_url": "https://ai.miket.tail:8000/v1",
    "api_key_env": "AI_PROXY_API_KEY",
    "model": "gpt-4.1-mini"
  }
  ```
  Set the environment variable in PowerShell before launching clients:
  ```powershell
  $env:AI_PROXY_API_KEY = (vault kv get -field=token ai/proxy/api-key)
  ```

- **Linux:** Keep the profile in `~/.config/miket/ai-profile.json` and export the key via your shell profile or a systemd user drop-in:
  ```json
  {
    "base_url": "https://ai.miket.tail:8000/v1",
    "api_key_env": "AI_PROXY_API_KEY",
    "model": "gpt-4.1-mini"
  }
  ```
  For long-running services, set `Environment=AI_PROXY_API_KEY=$(vault kv get -field=token ai/proxy/api-key)` inside the unit file.

## Latency and throughput considerations
- **Local vLLM (on-tailnet):** Lowest latency (sub-20 ms first-token on LAN) and highest throughput (50–80 tok/s for short prompts) when connecting to `ai.miket.tail:8000` directly.
- **Cloud backends (remote hops):** Expect extra 40–80 ms round-trip latency and ~10–20% lower sustained tokens/s because of cross-region transit. Prefer the local endpoint for interactive editing (Obsidian) and iterative dev (Trailblazer); fall back to cloud only when models are unavailable locally.
