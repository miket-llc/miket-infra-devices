# Account Architecture

This reference captures account types on PHC-managed devices. Identity is Entra-first for services, with a local automation account for configuration management.

## Three-layer model

### 1) User accounts (context-specific)
| Context | Provider | Example | Usage |
| --- | --- | --- | --- |
| Personal | Local | `miket` | Daily personal use, gaming, local dev | 
| Business | Entra ID | `mike@miket.io` | Business services, SSO (Nextcloud, Cloudflare Access) |
| Day job | Employer | varies | Employer-managed resources |

Characteristics:
- Multiple user accounts can coexist on a device.
- User accounts are for interactive logins only; privileges follow least-privilege per context.

### 2) Automation account (`mdt`)
- Local account on **all** devices with sudo/Administrator rights.
- Used only by Ansible and automation (not daily work).
- Credentials sourced from **Azure Key Vault** via `secrets-sync`; `.env` caches (e.g., `/etc/ansible/windows-automation.env`) supply passwords to automation.
- SSH keys/WinRM creds tied to `mdt`; access restricted via Tailscale ACL + host firewall.

### 3) Service accounts (future)
- Prefer Entra app registrations/service principals when services require dedicated identities.
- Managed in `miket-infra`; consumed here through AKV-mapped secrets.

## Access control pattern
1. Tailscale ACLs grant network reachability based on device tags (`tag:server`, `tag:workstation`, `tag:macos`).
2. Host firewalls mirror ACL intent (defense in depth).
3. Automation uses `mdt`; human SSO uses Entra (Cloudflare Access, Nextcloud OIDC) where supported.

## Credential handling
- **SoR:** Azure Key Vault. Env files produced by `ansible/playbooks/secrets-sync.yml` hold cached credentials (0600 perms).
- **Humans:** 1Password only.
- **Transitional:** Ansible Vault allowed only while migrating secrets into AKV; new secrets must land in AKV first.

## Related artifacts
- Mount/user expectations: `docs/architecture/FILESYSTEM_ARCHITECTURE.md`
- Secrets mapping: `ansible/secrets-map.yml`
- Tailscale integration overview: `docs/architecture/PHC_VNEXT_ARCHITECTURE.md`
