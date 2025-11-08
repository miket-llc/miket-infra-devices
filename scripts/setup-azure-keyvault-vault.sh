#!/bin/bash
# Setup script for Azure Key Vault integration with Ansible Vault
# This script helps configure Azure Key Vault as the source for Ansible vault password

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}Azure Key Vault Setup for Ansible Vault${NC}"
echo ""

# Check Azure CLI
if ! command -v az >/dev/null 2>&1; then
    echo -e "${YELLOW}Azure CLI not found. Installing...${NC}"
    curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
fi

# Check if logged in
if ! az account show >/dev/null 2>&1; then
    echo -e "${YELLOW}Not logged in to Azure. Please login:${NC}"
    az login
fi

# Get Key Vault name
read -p "Azure Key Vault name [miket-infra-secrets]: " KEY_VAULT_NAME
KEY_VAULT_NAME=${KEY_VAULT_NAME:-miket-infra-secrets}

# Verify Key Vault exists
if ! az keyvault show --name "$KEY_VAULT_NAME" >/dev/null 2>&1; then
    echo -e "${RED}Error: Key Vault '$KEY_VAULT_NAME' not found${NC}"
    echo "Available Key Vaults:"
    az keyvault list --query [].name -o table
    exit 1
fi

echo -e "${GREEN}✓ Key Vault found: $KEY_VAULT_NAME${NC}"

# Get secret name
SECRET_NAME="${ANSIBLE_VAULT_SECRET_NAME:-ansible-vault-password}"
read -p "Secret name [$SECRET_NAME]: " INPUT_SECRET_NAME
SECRET_NAME=${INPUT_SECRET_NAME:-$SECRET_NAME}

# Check if secret already exists
if az keyvault secret show --vault-name "$KEY_VAULT_NAME" --name "$SECRET_NAME" >/dev/null 2>&1; then
    echo -e "${YELLOW}Secret '$SECRET_NAME' already exists in Key Vault${NC}"
    read -p "Update existing secret? (y/N): " UPDATE_SECRET
    if [[ ! "$UPDATE_SECRET" =~ ^[Yy]$ ]]; then
        echo "Skipping secret creation."
        exit 0
    fi
fi

# Get vault password
echo ""
echo -e "${YELLOW}Enter the Ansible vault password:${NC}"
echo "You can get it from 1Password or enter it manually."
read -sp "Vault password: " VAULT_PASSWORD
echo ""

# Store in Key Vault
echo -e "${GREEN}Storing password in Azure Key Vault...${NC}"
az keyvault secret set \
    --vault-name "$KEY_VAULT_NAME" \
    --name "$SECRET_NAME" \
    --value "$VAULT_PASSWORD" \
    >/dev/null

echo -e "${GREEN}✓ Password stored in Azure Key Vault${NC}"

# Test retrieval
echo -e "${GREEN}Testing password retrieval...${NC}"
if ./scripts/ansible-vault-password.sh >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Password retrieval successful${NC}"
else
    echo -e "${RED}✗ Password retrieval failed${NC}"
    echo "Check Azure authentication and Key Vault permissions"
    exit 1
fi

# Update environment variables (optional)
echo ""
echo -e "${YELLOW}To use Azure Key Vault, set these environment variables (optional):${NC}"
echo "export AZURE_KEY_VAULT_NAME=\"$KEY_VAULT_NAME\""
echo "export ANSIBLE_VAULT_SECRET_NAME=\"$SECRET_NAME\""
echo ""
echo -e "${GREEN}Setup complete!${NC}"
echo ""
echo "The ansible.cfg is already configured to use the multi-source script."
echo "It will try Azure Key Vault first, then fall back to 1Password if needed."

