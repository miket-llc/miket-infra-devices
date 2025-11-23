# Ansible Automation

This directory houses inventories, playbooks, and reusable roles for automating configuration across the fleet. Keep environment-specific variables separated so production and lab assets can be targeted safely.

## Inventory group conventions

The shared inventory (`inventory/hosts.yml`) defines host operating-system families along with capability-oriented groups that make targeting GPU or Wake-on-LAN ready systems straightforward:

| Group | Purpose | Typical usage |
| ----- | ------- | ------------- |
| `gpu_8gb` | Linux and Windows nodes with ~8 GB of dedicated GPU VRAM | `ansible-playbook playbooks/gpu-driver.yml -l gpu_8gb` |
| `gpu_12gb` | Windows nodes with 12 GB+ VRAM suitable for heavier ML jobs | `ansible-playbook playbooks/vllm.yml -l gpu_12gb` |
| `wol_enabled` | Devices that can be powered on remotely via Wake-on-LAN | `ansible-playbook playbooks/power/wol.yml -l wol_enabled` |

When adding a new host, place it under the appropriate OS family and opt in to any capability groupings it supports. This keeps playbooks focused on the features they configure rather than specific device names.

## Ansible Vault

Automation secrets now flow from Azure Key Vault into host-local `.env` files via the `secrets_sync` role. Update or extend the
mapping in `ansible/secrets-map.yml`, then run:

```bash
ansible-playbook -i inventory/hosts.yml playbooks/secrets-sync.yml --limit motoko
```

For Windows automation, export the generated `/etc/ansible/windows-automation.env` before running playbooks so `ansible_password`
lookups resolve without prompting:

```bash
set -a
source /etc/ansible/windows-automation.env
set +a
```

> Legacy Ansible Vault files remain for reference/bootstrapping but should be migrated to Azure Key Vault-backed secrets.

### Azure Key Vault → env files (preferred)

- Automation secrets are sourced from Azure Key Vault and written to device-local env files via `ansible/playbooks/secrets-sync.yml`.
- Add or update secrets by editing `ansible/secrets-map.yml` and rerunning the sync playbook.
- 1Password remains for human access only; avoid wiring automation to `op` sessions.
- Keep Ansible Vault limited to bootstrap credentials required to reach AKV.

## Devices Infrastructure Playbooks

Comprehensive playbooks for deploying and managing mounts, OS cloud sync, and devices view across all platforms.

### Quick Deployment

```bash
# Deploy everything (server + all clients)
ansible-playbook -i inventory/hosts.yml playbooks/deploy-devices-infrastructure.yml

# Validate deployment
ansible-playbook -i inventory/hosts.yml playbooks/validate-devices-infrastructure.yml
```

### Individual Playbooks

| Playbook | Purpose | Target Hosts |
|----------|---------|--------------|
| `deploy-devices-infrastructure.yml` | Master orchestration (all phases) | motoko, macos, windows |
| `deploy-mounts-macos.yml` | macOS mount configuration (/mkt/*, symlinks) | macos |
| `deploy-mounts-windows.yml` | Windows drive mappings (X:, S:, T:) | windows |
| `deploy-oscloud-sync.yml` | OS cloud sync to /space/devices | macos, windows |
| `motoko/setup-devices-structure.yml` | Server-side /space/devices setup | motoko |
| `validate-devices-infrastructure.yml` | Comprehensive validation checks | all |

### Deployment Tags

Use tags for selective deployment:

```bash
# Deploy only server setup
ansible-playbook -i inventory/hosts.yml playbooks/deploy-devices-infrastructure.yml --tags server

# Deploy only mount configuration
ansible-playbook -i inventory/hosts.yml playbooks/deploy-devices-infrastructure.yml --tags mounts

# Deploy only OS cloud sync
ansible-playbook -i inventory/hosts.yml playbooks/deploy-devices-infrastructure.yml --tags oscloud

# Deploy only to macOS
ansible-playbook -i inventory/hosts.yml playbooks/deploy-devices-infrastructure.yml --tags macos

# Deploy only to Windows
ansible-playbook -i inventory/hosts.yml playbooks/deploy-devices-infrastructure.yml --tags windows
```

### What Gets Deployed

**macOS:**
- System-level SMB mounts: `/mkt/flux`, `/mkt/space`, `/mkt/time`
- User symlinks: `~/flux`, `~/space`, `~/time`
- OS cloud sync scripts (iCloud, OneDrive)
- LaunchAgents for automation
- Loop prevention checks

**Windows:**
- Network drives: `X:` (FLUX), `S:` (SPACE), `T:` (TIME)
- Drive labels for user-friendly display
- Quick Access pinning
- OS cloud sync scripts (OneDrive, iCloud)
- Scheduled tasks for automation
- Loop prevention checks

**Server (motoko):**
- `/space/devices/<hostname>/<username>/` structure
- `/space/mike/devices` → `/space/devices` symlink
- Device subdirectories for known hosts

### Post-Deployment

Users must:
1. Log out/in (macOS) or log off/on (Windows)
2. Verify mounts/drives accessible
3. Run loop check scripts (warnings about OS cloud config)
4. Configure iCloud/OneDrive to exclude network drives

### Related Roles

| Role | Purpose |
|------|---------|
| `mount_shares_macos` | macOS SMB mount configuration |
| `mount_shares_windows` | Windows network drive mappings |
| `oscloud_sync` | OS cloud synchronization (cross-platform) |
| `devices_structure` | Server-side /space/devices setup |

### Documentation

- **Deployment Guide:** [docs/runbooks/devices-infrastructure-deployment.md](../docs/runbooks/devices-infrastructure-deployment.md)
- **Implementation Log:** [docs/communications/COMMUNICATION_LOG.md](../docs/communications/COMMUNICATION_LOG.md#2025-11-20-devices-infra)
