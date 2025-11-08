# Azure Key Vault Integration for Ansible Vault

This document explains how to configure Azure Key Vault as the source for the Ansible vault password, enabling automated access without interactive authentication.

## Overview

Azure Key Vault provides a secure, cloud-based solution for storing the Ansible vault password. This allows:
- **Automated access** without requiring physical access to motoko
- **Managed Identity support** for Azure-hosted resources
- **Service Principal authentication** for CI/CD pipelines
- **Audit logging** of vault password access
- **Centralized secret management** alongside other infrastructure secrets

## Prerequisites

1. **Azure Key Vault** created and accessible
2. **Azure CLI** installed on motoko: `curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash`
3. **Azure authentication** configured (see options below)

## Setup Steps

### Step 1: Store Vault Password in Azure Key Vault

```bash
# Login to Azure (if not already logged in)
az login

# Set your Key Vault name (or use default: miket-infra-secrets)
export KEY_VAULT_NAME="miket-infra-secrets"
export SECRET_NAME="ansible-vault-password"

# Store the vault password in Key Vault
# Get your current vault password first
CURRENT_PASSWORD=$(op read "op://miket.io/Ansible - Motoko Key Vault/password" 2>/dev/null || read -sp "Enter vault password: " CURRENT_PASSWORD && echo)

# Store in Azure Key Vault
az keyvault secret set \
    --vault-name "$KEY_VAULT_NAME" \
    --name "$SECRET_NAME" \
    --value "$CURRENT_PASSWORD"
```

### Step 2: Configure Authentication

Choose one of the following authentication methods:

#### Option A: Azure CLI Login (Interactive)

```bash
# Login interactively (good for initial setup)
az login

# Verify access
az keyvault secret show \
    --vault-name "miket-infra-secrets" \
    --name "ansible-vault-password" \
    --query value -o tsv
```

#### Option B: Service Principal (Recommended for Automation)

```bash
# Create service principal (if you don't have one)
az ad sp create-for-rbac --name "ansible-automation" --skip-assignment

# Grant Key Vault access to service principal
SP_APP_ID="<your-service-principal-app-id>"
az keyvault set-policy \
    --name "miket-infra-secrets" \
    --spn "$SP_APP_ID" \
    --secret-permissions get list

# Login with service principal
az login --service-principal \
    --username "$SP_APP_ID" \
    --password "<service-principal-password>" \
    --tenant "<your-tenant-id>"
```

#### Option C: Managed Identity (If motoko runs in Azure)

If motoko is running as an Azure VM or Azure Arc-enabled server:

```bash
# Assign managed identity to VM (via Azure Portal or CLI)
# Then configure Key Vault access policy for the managed identity
az keyvault set-policy \
    --name "miket-infra-secrets" \
    --object-id "<managed-identity-object-id>" \
    --secret-permissions get list

# Managed identity will be used automatically - no login needed!
```

### Step 3: Update Ansible Configuration

Update `ansible/ansible.cfg` to use the Azure Key Vault script:

```ini
[defaults]
vault_password_file = /home/mdt/miket-infra-devices/scripts/ansible-vault-password.sh
```

Or use the Azure-only script:

```ini
[defaults]
vault_password_file = /home/mdt/miket-infra-devices/scripts/ansible-vault-password-azure.sh
```

### Step 4: Test the Integration

```bash
# Test the script directly
cd ~/miket-infra-devices
./scripts/ansible-vault-password.sh

# Test with Ansible
ansible-vault view ansible/group_vars/windows/vault.yml

# Test playbook execution
ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/test-connectivity.yml --limit wintermute
```

## Environment Variables

Customize the script behavior with environment variables:

```bash
# Set Key Vault name (default: miket-infra-secrets)
export AZURE_KEY_VAULT_NAME="your-key-vault-name"

# Set secret name (default: ansible-vault-password)
export ANSIBLE_VAULT_SECRET_NAME="ansible-vault-password"

# Use in ansible.cfg or export before running Ansible
```

## Multi-Source Fallback Script

The `ansible-vault-password.sh` script supports multiple sources with automatic fallback:

1. **Azure Key Vault** (primary for automation)
2. **1Password** (fallback for manual operations)
3. **Local password file** (fallback for offline scenarios)

This ensures reliability while prioritizing automated access.

## Security Best Practices

1. **Least Privilege**: Grant only `get` and `list` permissions on the specific secret
2. **Access Policies**: Use Azure RBAC or Key Vault access policies to limit access
3. **Audit Logging**: Enable Key Vault diagnostic settings to log all access
4. **Secret Rotation**: Rotate the vault password periodically:
   ```bash
   # Generate new password
   NEW_PASSWORD=$(openssl rand -base64 32)
   
   # Update in Key Vault
   az keyvault secret set --vault-name "miket-infra-secrets" \
       --name "ansible-vault-password" --value "$NEW_PASSWORD"
   
   # Re-encrypt all vault files with new password
   ansible-vault rekey ansible/group_vars/windows/vault.yml
   ```

5. **Network Restrictions**: Use Key Vault firewall rules to restrict access to trusted IPs/networks

## Troubleshooting

### "Not logged in to Azure"
```bash
az login
```

### "Access denied to Key Vault"
```bash
# Check your permissions
az keyvault show --name "miket-infra-secrets" --query properties.accessPolicies

# Grant yourself access (if you're an admin)
az keyvault set-policy \
    --name "miket-infra-secrets" \
    --upn "$(az account show --query user.name -o tsv)" \
    --secret-permissions get list
```

### "Key Vault not found"
- Verify the Key Vault name: `az keyvault list --query [].name`
- Check you're in the correct subscription: `az account show`

### Script falls back to 1Password
- This is expected if Azure Key Vault is unavailable
- Check Azure CLI authentication: `az account show`
- Verify Key Vault access: `az keyvault secret show --vault-name "..." --name "..."`

## Migration from 1Password

To migrate from 1Password to Azure Key Vault:

```bash
# 1. Get current password from 1Password
CURRENT_PASS=$(op read "op://miket.io/Ansible - Motoko Key Vault/password")

# 2. Store in Azure Key Vault
az keyvault secret set \
    --vault-name "miket-infra-secrets" \
    --name "ansible-vault-password" \
    --value "$CURRENT_PASS"

# 3. Update ansible.cfg to use Azure script
# 4. Test the new setup
# 5. Keep 1Password as backup until confident in Azure setup
```

## Related Documentation

- [Ansible Vault Setup](./ansible-vault-setup.md)
- [Azure Key Vault Documentation](https://docs.microsoft.com/azure/key-vault/)
- [Azure CLI Authentication](https://docs.microsoft.com/cli/azure/authenticate-azure-cli)

