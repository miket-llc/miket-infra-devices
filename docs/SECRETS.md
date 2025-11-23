# Secrets Management (Azure Key Vault → device `.env`)

Automation secrets live in Azure Key Vault (`kv-miket-ops`) and are rendered into device-local `.env` files via `ansible/playbooks/secrets-sync.yml`. Services only read environment variables or env files. 1Password is for humans/break-glass only.

## Inventory

| Env Var | AKV Secret | Purpose / Service | Env File (host/group) |
| --- | --- | --- | --- |
| `OPENAI_API_KEY` | `openai-api-key` | LiteLLM upstream OpenAI key | `/opt/litellm/.env` (motoko) |
| `LITELLM_TOKEN` | `litellm-bearer-token` | LiteLLM client auth token | `/opt/litellm/.env` (motoko) |
| `B2_APPLICATION_KEY_ID` | `b2-space-mirror-id` | Rclone mirror identity | `/etc/miket/storage-credentials.env` (motoko) |
| `B2_APPLICATION_KEY` | `b2-space-mirror-key` | Rclone mirror secret | `/etc/miket/storage-credentials.env` (motoko) |
| `B2_ACCOUNT_ID` | `b2-restic-id` | Restic backup identity | `/etc/miket/storage-credentials.env` (motoko) |
| `B2_ACCOUNT_KEY` | `b2-restic-key` | Restic backup secret | `/etc/miket/storage-credentials.env` (motoko) |
| `RESTIC_PASSWORD` | `restic-password` | Restic repo password | `/etc/miket/storage-credentials.env` (motoko) |
| `ARMITAGE_ANSIBLE_PASSWORD` | `armitage-ansible-password` | WinRM password for armitage | `/etc/ansible/windows-automation.env` (motoko) |
| `WINTERMUTE_ANSIBLE_PASSWORD` | `wintermute-ansible-password` | WinRM password for wintermute | `/etc/ansible/windows-automation.env` (motoko) |
| `SMB_PASSWORD` | `motoko-smb-password` | macOS SMB mount password | `~/.mkt/mounts.env` (macos group) |

Additions only require editing `ansible/secrets-map.yml`; the role consumes new entries automatically.

## AKV → .env sync

- Mapping file: `ansible/secrets-map.yml` (per-service `env_file`, `secrets`, optional `hosts`/`groups`, `restart`).
- Playbook: `ansible/playbooks/secrets-sync.yml` (runs `roles/secrets_sync`).
- Role: reads the mapping, pulls each AKV secret with Azure CLI (run as `run_as` per entry), writes `KEY=VALUE` lines with restrictive permissions, and restarts listed services.

Usage:
```bash
# Sync a single host
ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/secrets-sync.yml --limit motoko

# Sync everything mapped
ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/secrets-sync.yml
```

Service expectations:
- LiteLLM: `/opt/litellm/.env` must contain `OPENAI_API_KEY` and `LITELLM_TOKEN`.
- Data lifecycle timers: `/etc/miket/storage-credentials.env` provides Backblaze + Restic creds.
- Windows automation: `set -a; source /etc/ansible/windows-automation.env; set +a` before running WinRM playbooks.
- macOS mounts: `~/.mkt/mounts.env` provides `SMB_PASSWORD` for `mount_shares_macos`.

## Migration checklist

1) Populate AKV (`kv-miket-ops`) with these secrets:  
`openai-api-key`, `litellm-bearer-token`, `b2-space-mirror-id`, `b2-space-mirror-key`, `b2-restic-id`, `b2-restic-key`, `restic-password`, `armitage-ansible-password`, `wintermute-ansible-password`, `motoko-smb-password`.

2) Run sync:  
`ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/secrets-sync.yml --limit motoko`  
`ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/secrets-sync.yml --limit macos`

3) Verify env files and permissions (0600, correct owner):  
- `/opt/litellm/.env`  
- `/etc/miket/storage-credentials.env`  
- `/etc/ansible/windows-automation.env`  
- `~/.mkt/mounts.env` on macOS hosts

4) Consume Windows env before playbooks:  
`set -a; source /etc/ansible/windows-automation.env; set +a`

5) Retire legacy secrets:  
- Move any remaining values from vaulted files (`ansible/group_vars/all/vault.yml`, `ansible/group_vars/linux/vault.yml`, `ansible/group_vars/windows/vault.yml`, `ansible/host_vars/armitage_vault.yml`) into AKV, then delete the vault entries.  
- `ansible/host_vars/wintermute/password.yml` is now a placeholder; do not store passwords there.  
- Do not add new Ansible Vault data; keep Vault only for short-lived bootstrap if absolutely required.

6) 1Password automation is deprecated: keep `op` for humans only; automation must rely on AKV→env via `secrets-sync`.
