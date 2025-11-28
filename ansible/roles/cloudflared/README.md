# Cloudflared Ansible Role

Installs and configures the Cloudflare Tunnel connector (cloudflared) on Linux hosts.

## Overview

This role:
1. Installs cloudflared from GitHub releases
2. Fetches tunnel credentials from Azure Key Vault
3. Configures ingress rules for routing traffic
4. Sets up systemd service for automatic startup

## Requirements

- Azure CLI authenticated with access to Key Vault
- Tunnel must be pre-created (via Terraform in miket-infra or cloudflared CLI)
- Tunnel credentials stored in AKV

## Role Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `cloudflared_tunnel_id` | Yes | - | UUID of the Cloudflare tunnel |
| `cloudflared_akv_secret_name` | Yes | - | AKV secret name containing credentials |
| `cloudflared_tunnel_name` | No | "default" | Human-readable tunnel name |
| `cloudflared_ingress_rules` | No | [] | List of hostname/service mappings |
| `cloudflared_akv_vault_name` | No | "kv-miket-ops" | Azure Key Vault name |

## Example Playbook

```yaml
- hosts: motoko
  become: true
  roles:
    - role: cloudflared
      vars:
        cloudflared_tunnel_id: "b8073aa7-29ce-4bd9-8e9a-186ba69575b3"
        cloudflared_tunnel_name: "motoko-phc"
        cloudflared_akv_secret_name: "cloudflare-tunnel-motoko-credentials"
        cloudflared_ingress_rules:
          - hostname: nextcloud.miket.io
            service: http://localhost:8080
```

## Architecture

```
Internet → Cloudflare Edge → Tunnel → cloudflared (this role) → Local Services
                ↓
         Cloudflare Access
         (Entra ID SSO)
```

## Adding New Services

1. Add ingress rule to `cloudflared_ingress_rules`
2. Add DNS record in miket-infra (Terraform)
3. Re-run playbook

## Troubleshooting

```bash
# Check service status
systemctl status cloudflared

# View logs
journalctl -u cloudflared -f

# Validate config
cloudflared tunnel --config /root/.cloudflared/config.yml ingress validate

# Test tunnel connectivity
cloudflared tunnel --config /root/.cloudflared/config.yml run
```

