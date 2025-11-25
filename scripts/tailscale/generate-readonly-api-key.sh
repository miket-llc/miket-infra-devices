#!/bin/bash
# Copyright (c) 2025 MikeT LLC. All rights reserved.

# Generate Tailscale Read-Only API Key for ACL Drift Detection
# Wave 2: Tailscale ACL drift check automation

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}Tailscale Read-Only API Key Generation${NC}"
echo -e "${CYAN}========================================${NC}\n"

echo -e "${YELLOW}This script will guide you through generating a read-only Tailscale API key.${NC}\n"

echo -e "${GREEN}Step 1: Open Tailscale Admin Console${NC}"
echo -e "URL: ${CYAN}https://login.tailscale.com/admin/settings/keys${NC}\n"

echo -e "${GREEN}Step 2: Generate API Key${NC}"
echo -e "1. Click ${CYAN}'Generate API key'${NC} or ${CYAN}'Generate access token'${NC}"
echo -e "2. Fill in the following details:\n"

echo -e "${YELLOW}Description:${NC}"
echo -e "  ${CYAN}Device Team - Read-Only ACL Drift Detection (Wave 2)${NC}\n"

echo -e "${YELLOW}Expiry:${NC}"
echo -e "  ${CYAN}90 days${NC}\n"

echo -e "${YELLOW}Scopes (READ-ONLY ONLY):${NC}"
echo -e "  ${GREEN}✅${NC} ${CYAN}devices:read${NC} (read device information)"
echo -e "  ${GREEN}✅${NC} ${CYAN}acl:read${NC} (read ACL configuration)"
echo -e "  ${RED}❌${NC} ${CYAN}devices:write${NC} (DO NOT ENABLE)"
echo -e "  ${RED}❌${NC} ${CYAN}acl:write${NC} (DO NOT ENABLE)"
echo -e "  ${RED}❌${NC} ${CYAN}keys:write${NC} (DO NOT ENABLE)\n"

echo -e "${GREEN}Step 3: Copy the API Key${NC}"
echo -e "The API key will be displayed once. Copy it immediately.\n"

read -p "Press Enter when you have the API key copied..."

echo -e "\n${GREEN}Step 4: Store the API Key Securely${NC}\n"

echo -e "${YELLOW}Option 1: Environment Variable (Temporary)${NC}"
echo -e "  ${CYAN}export TAILSCALE_API_KEY='tskey-api-readonly-...'${NC}\n"

echo -e "${YELLOW}Option 2: Azure Key Vault (Recommended)${NC}"
echo -e "  Store in Azure Key Vault: ${CYAN}tailscale-api-key-readonly${NC}\n"

echo -e "${YELLOW}Option 3: GitHub Secrets (CI/CD)${NC}"
echo -e "  Add to GitHub repository secrets: ${CYAN}TAILSCALE_API_KEY${NC}\n"

echo -e "${YELLOW}Option 4: Ansible Vault (Local)${NC}"
echo -e "  Store in ${CYAN}ansible/group_vars/all/vault.yml${NC}\n"

echo -e "${GREEN}Step 5: Test the API Key${NC}\n"

read -p "Enter the API key to test (or press Enter to skip): " API_KEY

if [ -n "$API_KEY" ]; then
    echo -e "\n${CYAN}Testing API key...${NC}\n"
    
    TAILNET="tail2e55fe.ts.net"
    
    # Test ACL endpoint
    echo -e "${YELLOW}Testing ACL endpoint...${NC}"
    ACL_RESPONSE=$(curl -s -u "${API_KEY}:" \
        "https://api.tailscale.com/api/v2/tailnet/${TAILNET}/acl" || echo "FAILED")
    
    if echo "$ACL_RESPONSE" | grep -q "tagOwners\|acls"; then
        echo -e "${GREEN}✅ ACL endpoint: SUCCESS${NC}\n"
    else
        echo -e "${RED}❌ ACL endpoint: FAILED${NC}"
        echo -e "Response: ${ACL_RESPONSE:0:200}\n"
    fi
    
    # Test Devices endpoint
    echo -e "${YELLOW}Testing Devices endpoint...${NC}"
    DEVICES_RESPONSE=$(curl -s -u "${API_KEY}:" \
        "https://api.tailscale.com/api/v2/tailnet/${TAILNET}/devices" || echo "FAILED")
    
    if echo "$DEVICES_RESPONSE" | grep -q "devices\|hostname"; then
        echo -e "${GREEN}✅ Devices endpoint: SUCCESS${NC}\n"
    else
        echo -e "${RED}❌ Devices endpoint: FAILED${NC}"
        echo -e "Response: ${DEVICES_RESPONSE:0:200}\n"
    fi
    
    echo -e "${GREEN}API key test complete!${NC}\n"
else
    echo -e "${YELLOW}Skipping API key test.${NC}\n"
fi

echo -e "${GREEN}Step 6: Configure in Ansible Playbook${NC}\n"

echo -e "${YELLOW}To use the API key in playbooks:${NC}"
echo -e "  ${CYAN}export TAILSCALE_API_KEY='tskey-api-readonly-...'${NC}"
echo -e "  ${CYAN}ansible-playbook -i ansible/inventory/hosts.yml \\${NC}"
echo -e "    ${CYAN}ansible/playbooks/validate-tailscale-acl-drift.yml${NC}\n"

echo -e "${GREEN}Step 7: Document Expiry Date${NC}\n"
read -p "Enter expiry date (YYYY-MM-DD) or press Enter to skip: " EXPIRY_DATE

if [ -n "$EXPIRY_DATE" ]; then
    echo -e "\n${YELLOW}Expiry Date: ${CYAN}${EXPIRY_DATE}${NC}"
    echo -e "${YELLOW}Set calendar reminder to rotate key before expiry!${NC}\n"
fi

echo -e "${CYAN}========================================${NC}"
echo -e "${GREEN}API Key Generation Complete!${NC}"
echo -e "${CYAN}========================================${NC}\n"

echo -e "${YELLOW}Security Notes:${NC}"
echo -e "  • Never commit API key to Git"
echo -e "  • Store securely (Azure Key Vault, GitHub Secrets, etc.)"
echo -e "  • Rotate every 90 days"
echo -e "  • Document expiry date and set calendar reminder\n"

echo -e "${YELLOW}Next Steps:${NC}"
echo -e "  1. Store API key securely"
echo -e "  2. Test ACL drift check playbook"
echo -e "  3. Schedule weekly drift checks\n"

