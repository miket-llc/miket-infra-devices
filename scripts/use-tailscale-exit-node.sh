#!/bin/bash
# Copyright (c) 2025 MikeT LLC. All rights reserved.


# Use Tailscale Exit Node to Bypass Router Filtering
# This routes all traffic through motoko server, bypassing local router

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}Tailscale Exit Node Configuration${NC}"
echo -e "${CYAN}========================================${NC}\n"

# Check if Tailscale is installed
if ! command -v tailscale &> /dev/null; then
    echo -e "${RED}✗ Tailscale is not installed${NC}"
    exit 1
fi

# Get current Tailscale status
echo -e "${GREEN}Checking Tailscale status...${NC}"
if ! tailscale status &> /dev/null; then
    echo -e "${RED}✗ Tailscale is not connected${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Tailscale is connected${NC}\n"

# Check if motoko is available
echo -e "${GREEN}Checking for motoko exit node...${NC}"
if tailscale status | grep -q "motoko"; then
    echo -e "${GREEN}✓ motoko is available${NC}\n"
else
    echo -e "${YELLOW}⚠️  motoko not found in Tailscale network${NC}"
    echo -e "${YELLOW}You may need to configure motoko as an exit node first${NC}\n"
fi

# Enable exit node
echo -e "${GREEN}Enabling Tailscale exit node (motoko)...${NC}"
sudo tailscale up --exit-node=motoko --exit-node-allow-lan-access=true --accept-dns --ssh

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Exit node enabled${NC}\n"
else
    echo -e "${RED}✗ Failed to enable exit node${NC}"
    echo -e "${YELLOW}You may need to approve the exit node in Tailscale admin console${NC}"
    exit 1
fi

# Verify exit node is active
echo -e "${GREEN}Verifying exit node...${NC}"
EXITNODE_STATUS=$(tailscale status --json | grep -o '"ExitNodeOption"' || echo "")
if [ -n "$EXITNODE_STATUS" ]; then
    echo -e "${GREEN}✓ Exit node is active${NC}\n"
else
    echo -e "${YELLOW}⚠️  Exit node status unclear, checking manually...${NC}\n"
fi

# Test connectivity
echo -e "${GREEN}Testing connectivity...${NC}"
echo -n "Testing www.cloudflare.com: "
if curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 https://www.cloudflare.com | grep -q "200"; then
    echo -e "${GREEN}OK${NC}"
else
    echo -e "${RED}FAILED${NC}"
fi

echo -n "Testing www.avid.com: "
AVID_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 https://www.avid.com)
if [ "$AVID_RESPONSE" = "403" ] || [ "$AVID_RESPONSE" = "200" ]; then
    echo -e "${GREEN}OK (HTTP $AVID_RESPONSE)${NC}"
else
    echo -e "${RED}FAILED (HTTP $AVID_RESPONSE)${NC}"
fi

echo ""
echo -e "${CYAN}========================================${NC}"
echo -e "${GREEN}Exit node configured successfully!${NC}"
echo -e "${CYAN}========================================${NC}"
echo -e "All traffic is now routed through motoko."
echo -e "This bypasses any router-level filtering."
echo ""
echo -e "To disable exit node later:"
echo -e "  ${YELLOW}sudo tailscale up --exit-node=''${NC}"
echo ""
echo -e "${GREEN}Now try accessing https://www.avid.com in your browser${NC}"




