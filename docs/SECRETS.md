# Secrets Management

Azure Key Vault (AKV) is the single source of truth for automation secrets. Ansible syncs those secrets into device-local `.env` files, and services consume environment variables only. 1Password remains for human access and break-glass scenarios but is not used by automation.

## Inventory

| Env Var | Purpose | AKV Secret Name | Consuming Service | Env File Path |
| --- | --- | --- | --- | --- |
| `OPENAI_API_KEY` | Upstream OpenAI access for LiteLLM routing | `openai-api-key` | LiteLLM proxy on motoko | `/opt/litellm/.env` |
| `LITELLM_TOKEN` | Bearer token required to call LiteLLM | `litellm-bearer-token` | LiteLLM proxy on motoko | `/opt/litellm/.env` |
| `B2_APPLICATION_KEY_ID` | Rclone mirror identity | `b2-space-mirror-id` | Flux/space mirror timer | `/etc/miket/storage-credentials.env` |
| `B2_APPLICATION_KEY` | Rclone mirror secret | `b2-space-mirror-key` | Flux/space mirror timer | `/etc/miket/storage-credentials.env` |
| `B2_ACCOUNT_ID` | Restic backup identity | `b2-restic-id` | Flux backup timer | `/etc/miket/storage-credentials.env` |
| `B2_ACCOUNT_KEY` | Restic backup secret | `b2-restic-key` | Flux backup timer | `/etc/miket/storage-credentials.env` |
| `RESTIC_PASSWORD` | Restic repository password | `restic-password` | Flux backup timer | `/etc/miket/storage-credentials.env` |
| `SMB_PASSWORD` | Motoko SMB mount credential | `motoko-smb-password` | macOS mount automation | `~/.mkt/mounts.env` |

## AKV → .env Sync

- Mapping file: `ansible/secrets-map.yml` (extend with new services/hosts; no code changes needed).
- Playbook: `ansible/playbooks/secrets-sync.yml`.
- Role: `ansible/roles/secrets_sync/` reads the mapping, pulls secrets from AKV via the Azure CLI, writes env files with `0600` permissions, and restarts dependent services listed per mapping entry.
- Default Key Vault: `kv-miket-ops` (override per entry).

### Usage

```bash
# Limit to a host
ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/secrets-sync.yml --limit motoko

# Sync everything defined in secrets-map.yml
ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/secrets-sync.yml
```

Services reference only the generated env files (Docker Compose env_file, systemd EnvironmentFile, or scripts that source the file). No playbooks embed raw secrets or Ansible Vault blobs.

## Migration Checklist

1. **Populate AKV** (all secrets names above under vault `kv-miket-ops`).
2. **Remove legacy Ansible Vault usage**
   - `ansible/group_vars/motoko.yml` currently references `vault_openai_api_key` and `vault_litellm_bearer_token`; migrate those values into AKV and remove the vault indirection when convenient.
   - `ansible/group_vars/linux/vault.yml` template remains as a bootstrap only; avoid adding new secrets there.
3. **Replace 1Password automation hooks**
   - The `systemd/op-session` helper is now human-only; automation should rely on `secrets-sync.yml` instead of `op` sessions.
4. **Verify**
   - Run `ansible/playbooks/secrets-sync.yml` for the relevant host(s).
   - Inspect env files for correct permissions and expected keys.
   - Restart dependent services if not already handled by the playbook.
   - For LiteLLM: ensure `/opt/litellm/.env` contains `OPENAI_API_KEY` and `LITELLM_TOKEN`, then rerun the LiteLLM playbook.

## Notes on Deprecated Paths

- Any remaining `ansible_vault` encrypted files are legacy and should only hold bootstrap material (e.g., credentials that allow AKV access). Do not add new secrets to Vault.
- 1Password (`op` CLI) stays for interactive human use; automation should not assume an active 1Password session.
