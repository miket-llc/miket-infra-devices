#!/bin/bash

# Enable Tailscale Exit Node and Test Cloudflare Access
# This script waits for exit node approval and then tests the fix

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}Tailscale Exit Node Activation${NC}"
echo -e "${CYAN}========================================${NC}\n"

echo -e "${YELLOW}Exit Node Approval Required:${NC}"
echo -e "1. Navigate to: ${GREEN}https://login.tailscale.com/admin/machines${NC}"
echo -e "2. Find 'motoko' in the machine list"
echo -e "3. Click the '...' menu next to motoko"
echo -e "4. Select 'Edit route settings...'"
echo -e "5. Check 'Use as exit node'"
echo -e "6. Click 'Save'"
echo -e ""

# Wait for approval
echo -e "${CYAN}Checking for exit node availability...${NC}"
MAX_ATTEMPTS=12
ATTEMPT=0

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    if tailscale exit-node list 2>&1 | grep -q "motoko"; then
        echo -e "${GREEN}✓ motoko exit node is approved and available!${NC}\n"
        break
    fi
    
    ATTEMPT=$((ATTEMPT + 1))
    if [ $ATTEMPT -lt $MAX_ATTEMPTS ]; then
        echo -n "."
        sleep 5
    else
        echo ""
        echo -e "${RED}✗ Exit node not approved after 60 seconds${NC}"
        echo -e "${YELLOW}Please approve the exit node in Tailscale admin console and run this script again${NC}"
        exit 1
    fi
done

# Enable exit node on count-zero
echo -e "${GREEN}Enabling exit node on count-zero...${NC}"
sudo tailscale up --exit-node=motoko --exit-node-allow-lan-access=true --accept-dns --ssh

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Exit node enabled${NC}\n"
else
    echo -e "${RED}✗ Failed to enable exit node${NC}"
    exit 1
fi

# Wait for routing to stabilize
echo -e "${CYAN}Waiting for routing to stabilize...${NC}"
sleep 3

# Test connectivity
echo -e "${GREEN}Testing connectivity through exit node...${NC}\n"

echo -n "Testing www.cloudflare.com: "
if curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 https://www.cloudflare.com | grep -q "200"; then
    echo -e "${GREEN}OK${NC}"
else
    echo -e "${RED}FAILED${NC}"
fi

echo -n "Testing challenges.cloudflare.com: "
CHALLENGE_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 https://challenges.cloudflare.com)
echo -e "${GREEN}HTTP $CHALLENGE_RESPONSE${NC}"

echo -n "Testing www.avid.com: "
AVID_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 https://www.avid.com)
if [ "$AVID_RESPONSE" = "403" ] || [ "$AVID_RESPONSE" = "200" ]; then
    echo -e "${GREEN}OK (HTTP $AVID_RESPONSE - Cloudflare challenge)${NC}"
else
    echo -e "${YELLOW}HTTP $AVID_RESPONSE${NC}"
fi

# Get public IP to verify we're routing through motoko
echo -e "\n${CYAN}Verifying exit node routing...${NC}"
PUBLIC_IP=$(curl -s https://api.ipify.org)
echo -e "Current public IP: ${GREEN}$PUBLIC_IP${NC}"
echo -e "(This should be motoko's public IP, not your local router's IP)\n"

echo -e "${CYAN}========================================${NC}"
echo -e "${GREEN}Setup Complete!${NC}"
echo -e "${CYAN}========================================${NC}"
echo -e "All traffic from count-zero is now routed through motoko."
echo -e "This bypasses any router-level filtering or blocking."
echo ""
echo -e "${GREEN}Now test in your browser:${NC}"
echo -e "1. Close all browser windows"
echo -e "2. Open a new browser window"
echo -e "3. Visit ${GREEN}https://www.avid.com${NC}"
echo -e "4. The Cloudflare challenge should complete successfully"
echo ""
echo -e "To disable exit node later:"
echo -e "  ${YELLOW}sudo tailscale up --exit-node=''${NC}"




