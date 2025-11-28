# Azure CLI Role

**Author:** MikeT LLC (Codex-PD-002)  
**Created:** 2025-11-25  
**Status:** Active  

## Overview

This Ansible role installs [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/) on all PHC endpoints. Azure CLI is **required** for accessing secrets from Azure Key Vault, which is the system of record for automation secrets in the PHC ecosystem.

## Why Azure CLI is Required

Per PHC invariant #3 (Secrets Architecture):
- Azure Key Vault (AKV) is the **system of record** for automation secrets
- Local `.env` files are ephemeral caches generated from AKV
- Ansible inventory uses `az keyvault secret show` for WinRM passwords
- Multiple roles depend on Azure CLI for Key Vault access

## Supported Platforms

| Platform | Status | Installation Method |
|----------|--------|---------------------|
| Ubuntu/Debian (Linux) | ✅ Full | Microsoft apt repository |
| macOS | ✅ Full | Homebrew |
| Windows | ✅ Full | winget (preferred) or MSI fallback |

## Requirements

### Linux (Debian/Ubuntu)
- apt package manager
- Internet access to packages.microsoft.com

### macOS
- Homebrew must be installed

### Windows
- winget (App Installer) preferred
- Falls back to MSI installer if winget unavailable

## Role Variables

```yaml
# defaults/main.yml
azure_cli_enabled: true
azure_cli_binary: /usr/bin/az
azure_keyvault_name: "kv-miket-ops"
azure_cli_verify_keyvault: false
```

## Usage

### Deploy to specific host

```bash
ansible-playbook -i inventory/hosts.yml playbooks/deploy-azure-cli.yml --limit motoko
```

### Deploy to all devices

```bash
ansible-playbook -i inventory/hosts.yml playbooks/deploy-azure-cli.yml
```

### As part of base deployment

Include in your deployment playbook:

```yaml
- hosts: all
  roles:
    - role: azure_cli
      tags:
        - azure
        - cli
        - prerequisites
```

## Post-Installation

1. **Authenticate:** Run `az login` to authenticate with Azure
2. **Verify Key Vault access:** 
   ```bash
   az keyvault secret list --vault-name kv-miket-ops --query "[].name" -o tsv
   ```
3. **For automation:** Use managed identity or service principal authentication

## PHC Integration

Azure CLI is a **prerequisite** for:
- `secrets_sync` role - syncs secrets from Key Vault to local env files
- `mount_shares_*` roles - retrieves SMB credentials
- `codex_cli` role - retrieves OpenAI API key
- Ansible inventory - WinRM password lookup for Windows hosts

## Dependencies

This role has no dependencies on other PHC roles. It should be deployed **first** as other roles depend on it.

## Troubleshooting

### Authentication Issues
```bash
# Re-authenticate
az login

# Check current account
az account show

# List subscriptions
az account list --output table
```

### Key Vault Access Issues
```bash
# Verify Key Vault exists
az keyvault show --name kv-miket-ops

# Check access policies
az keyvault show --name kv-miket-ops --query properties.accessPolicies

# Test secret access
az keyvault secret show --vault-name kv-miket-ops --name test-secret
```

## License

Copyright (c) 2025 MikeT LLC. All rights reserved.








