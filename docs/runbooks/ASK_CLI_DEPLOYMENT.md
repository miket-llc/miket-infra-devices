# ask-cli Deployment Runbook

This runbook covers deploying and managing the `ask` CLI tool across the fleet.

## Overview

The `ask` CLI is a lightweight LiteLLM client that connects to the LiteLLM proxy on akira. It's deployed via chezmoi with configuration managed centrally.

**Architecture:**
- **Binary installation**: Ansible clones and runs `install.sh` from `miket-llc/ask-cli`
- **Shell configuration**: chezmoi manages `ASK_BASE_URL`, `ASK_MODEL` in `~/.config/zsh/zshrc`
- **Version pinning**: Controlled in chezmoi's `.chezmoidata.yaml`
- **LiteLLM proxy**: `http://akira.pangolin-vega.ts.net:4001`

## Quick Reference

### Deploy to all Linux servers
```bash
ansible-playbook -i inventory/hosts.yml playbooks/deploy-chezmoi.yml
```

### Deploy to specific host
```bash
ansible-playbook -i inventory/hosts.yml playbooks/deploy-chezmoi.yml --limit armitage
```

### Verify installation on a host
```bash
ssh mdt@<host>.pangolin-vega.ts.net 'source ~/.config/zsh/zshrc && ask --print-config'
ssh mdt@<host>.pangolin-vega.ts.net 'source ~/.config/zsh/zshrc && ask --list-models'
ssh mdt@<host>.pangolin-vega.ts.net 'source ~/.config/zsh/zshrc && ask "hello"'
```

## Version Updates

To update the ask-cli version across all machines:

1. **Update the version pin in chezmoi:**
   ```bash
   chezmoi cd
   # Edit .chezmoidata.yaml
   ```

   Change the version:
   ```yaml
   ask:
     version: "v1.2.3"  # or "main" for latest
   ```

2. **Commit and push:**
   ```bash
   git add .chezmoidata.yaml
   git commit -m "chore: bump ask-cli to v1.2.3"
   git push
   ```

3. **Deploy to fleet:**
   ```bash
   ansible-playbook -i inventory/hosts.yml playbooks/deploy-chezmoi.yml
   ```

## Configuration Changes

### Change LiteLLM endpoint

1. **Update chezmoi data:**
   ```yaml
   # ~/.local/share/chezmoi/.chezmoidata.yaml
   ask:
     base_url: "http://new-host:4001"
   ```

2. **Commit and redeploy** (as above)

### Change default model

1. **Update chezmoi data:**
   ```yaml
   ask:
     default_model: "gpt-4"
   ```

2. **Commit and redeploy**

### Per-host overrides

Users can override settings locally via environment variables or:
```bash
# ~/.config/ask/secrets.env (not managed by chezmoi)
ASK_BASE_URL=http://custom-host:4001
ASK_MODEL=custom-model
ASK_API_KEY=optional-key
```

## API Key Management

The ask-cli uses LiteLLM's proxy which doesn't require per-user API keys by default. If API key auth is enabled on LiteLLM:

1. **Generate a key in LiteLLM:**
   ```bash
   # On akira
   curl -X POST http://localhost:4001/key/generate \
     -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
     -H "Content-Type: application/json" \
     -d '{"user_id": "mdt"}'
   ```

2. **Configure on client:**
   ```bash
   mkdir -p ~/.config/ask
   echo "ASK_API_KEY=sk-..." > ~/.config/ask/secrets.env
   chmod 600 ~/.config/ask/secrets.env
   ```

## Troubleshooting

### ask not found in PATH
```bash
# Ensure ~/.local/bin is in PATH
export PATH="$HOME/.local/bin:$PATH"

# Or reinstall
cd ~/.local/share/ask-cli && bash install.sh
```

### Connection refused / timeout
1. Check LiteLLM is running:
   ```bash
   curl http://akira.pangolin-vega.ts.net:4001/health
   ```

2. Check Tailscale connectivity:
   ```bash
   tailscale ping akira
   ```

3. Check firewall on akira:
   ```bash
   sudo firewall-cmd --list-ports
   ```

### Wrong model / endpoint
```bash
# Check current config
ask --print-config

# Verify zshrc has correct values
grep ASK_ ~/.config/zsh/zshrc

# Source the updated config
source ~/.config/zsh/zshrc
```

### GitHub SSH access denied (during chezmoi init)
The playbook deploys a GitHub deploy key from AKV. If access is denied:

1. Check key exists:
   ```bash
   ls -la ~/.ssh/github_deploy_key
   ```

2. Test SSH:
   ```bash
   ssh -T git@github.com
   ```

3. Re-deploy key from AKV:
   ```bash
   az keyvault secret show --vault-name kv-miket-ops \
     --name github-deploy-key --query value -o tsv > ~/.ssh/github_deploy_key
   chmod 600 ~/.ssh/github_deploy_key
   ```

## Infrastructure Components

### Files and Locations

| Component | Location | Managed By |
|-----------|----------|------------|
| ask binary | `~/.local/bin/ask` | Ansible/install.sh |
| ask source | `~/.local/share/ask-cli` | Ansible (git clone) |
| Shell config | `~/.config/zsh/zshrc` | chezmoi |
| Version pin | `~/.local/share/chezmoi/.chezmoidata.yaml` | chezmoi |
| API secrets | `~/.config/ask/secrets.env` | Manual (not in git) |
| GitHub key | `~/.ssh/github_deploy_key` | Ansible (from AKV) |

### Ansible Playbook
- `playbooks/deploy-chezmoi.yml` - Main deployment playbook

### AKV Secrets
- `github-deploy-key` - SSH private key for GitHub access

### GitHub
- Deploy key on `miket-llc/miket-dot-config` (read-only)

## Rollback

To rollback ask-cli to a previous version:

1. **Update version in chezmoidata:**
   ```yaml
   ask:
     version: "v1.1.0"  # Previous version
   ```

2. **Force reinstall:**
   ```bash
   # On each host or via Ansible
   rm -rf ~/.local/share/ask-cli
   ansible-playbook -i inventory/hosts.yml playbooks/deploy-chezmoi.yml --limit <host>
   ```

## Adding New Nodes

New Linux servers are automatically configured when added to the `linux_servers` group and running:
```bash
ansible-playbook -i inventory/hosts.yml playbooks/deploy-chezmoi.yml --limit <new-host>
```

The playbook handles:
- Installing shell packages (zsh, starship, neovim, etc.)
- Deploying GitHub SSH key from AKV
- Installing chezmoi
- Cloning dotfiles repo
- Installing ask-cli
