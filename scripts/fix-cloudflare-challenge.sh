#!/bin/bash
# Copyright (c) 2025 MikeT LLC. All rights reserved.


# Fix Cloudflare Challenge Blocking Issue
# This script fixes the "Please unblock challenges.cloudflare.com" error

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}Cloudflare Challenge Fix Script${NC}"
echo -e "${CYAN}========================================${NC}\n"

# Step 1: Set DNS to Cloudflare (bypass router DNS filtering)
echo -e "${GREEN}[1/5] Configuring DNS servers...${NC}"
networksetup -setdnsservers Wi-Fi 1.1.1.1 1.0.0.1
echo -e "${GREEN}✓ DNS set to Cloudflare (1.1.1.1, 1.0.0.1)${NC}\n"

# Step 2: Flush DNS cache
echo -e "${GREEN}[2/5] Flushing DNS cache...${NC}"
dscacheutil -flushcache
killall -HUP mDNSResponder 2>/dev/null || true
echo -e "${GREEN}✓ DNS cache flushed${NC}\n"

# Step 3: Remove any problematic /etc/hosts entries
echo -e "${GREEN}[3/5] Checking /etc/hosts for blocks...${NC}"
if grep -q "cloudflare.com" /etc/hosts 2>/dev/null; then
    echo -e "${YELLOW}Found cloudflare.com in /etc/hosts - manual removal required${NC}"
    echo -e "${YELLOW}Run: sudo nano /etc/hosts and remove any cloudflare.com entries${NC}"
else
    echo -e "${GREEN}✓ No cloudflare.com blocks in /etc/hosts${NC}"
fi
echo ""

# Step 4: Check for content blockers
echo -e "${GREEN}[4/5] Checking for content blockers...${NC}"
BLOCKERS=$(ps aux | grep -i "little.*snitch\|1blocker\|adguard" | grep -v grep || true)
if [ -n "$BLOCKERS" ]; then
    echo -e "${YELLOW}⚠️  Content blocking software detected:${NC}"
    echo "$BLOCKERS"
    echo -e "${YELLOW}Consider disabling these temporarily${NC}"
else
    echo -e "${GREEN}✓ No known content blockers running${NC}"
fi
echo ""

# Step 5: Test access
echo -e "${GREEN}[5/5] Testing access to Cloudflare and avid.com...${NC}"

echo -n "Testing www.cloudflare.com: "
if curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 https://www.cloudflare.com | grep -q "200"; then
    echo -e "${GREEN}OK${NC}"
else
    echo -e "${RED}FAILED${NC}"
fi

echo -n "Testing www.avid.com: "
AVID_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 https://www.avid.com)
if [ "$AVID_RESPONSE" = "403" ]; then
    echo -e "${YELLOW}Cloudflare Challenge (Expected - requires browser)${NC}"
elif [ "$AVID_RESPONSE" = "200" ]; then
    echo -e "${GREEN}OK${NC}"
else
    echo -e "${RED}FAILED (HTTP $AVID_RESPONSE)${NC}"
fi

echo ""
echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}Next Steps:${NC}"
echo -e "${CYAN}========================================${NC}"
echo -e "1. Close all browser windows"
echo -e "2. Open a new private/incognito window"
echo -e "3. Visit https://www.avid.com"
echo -e "4. The Cloudflare challenge should now complete automatically"
echo ""
echo -e "${YELLOW}If the issue persists, check your router settings:${NC}"
echo -e "  • Visit https://myfiosgateway.com"
echo -e "  • Go to Advanced > Security"
echo -e "  • Disable any DNS filtering or parental controls"
echo -e "  • Check for blocked domains lists"
echo ""
echo -e "${GREEN}Script complete!${NC}"




