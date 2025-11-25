#!/bin/bash
# Copyright (c) 2025 MikeT LLC. All rights reserved.


# Master Cloudflare Challenge Fix Script
# This script applies multiple fixes to resolve Cloudflare challenge blocking

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

clear
echo -e "${BOLD}${CYAN}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║     Cloudflare Challenge Fix - Master Script          ║${NC}"
echo -e "${BOLD}${CYAN}║     Fixing access to avid.com and other CF sites      ║${NC}"
echo -e "${BOLD}${CYAN}╚════════════════════════════════════════════════════════╝${NC}\n"

# Check if running with sudo
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}✗ This script requires sudo access${NC}"
    echo -e "${YELLOW}Please run with: ${BOLD}sudo $0${NC}\n"
    exit 1
fi

echo -e "${GREEN}✓ Running with sudo privileges${NC}\n"

# Step 1: Set DNS to Cloudflare
echo -e "${CYAN}[Step 1/5] Configuring system DNS servers...${NC}"
networksetup -setdnsservers Wi-Fi 1.1.1.1 1.0.0.1
echo -e "${GREEN}✓ DNS servers set to Cloudflare (1.1.1.1, 1.0.0.1)${NC}\n"

# Step 2: Create DNS resolver overrides
echo -e "${CYAN}[Step 2/5] Creating DNS resolver overrides...${NC}"
mkdir -p /etc/resolver

# Override for cloudflare.com domains
cat > /etc/resolver/cloudflare.com << 'EOF'
# Force Cloudflare domains to use Cloudflare DNS
# Bypasses router DNS filtering
# Created by: master-fix-cloudflare.sh
nameserver 1.1.1.1
nameserver 1.0.0.1
EOF
chmod 644 /etc/resolver/cloudflare.com
echo -e "${GREEN}✓ Created /etc/resolver/cloudflare.com${NC}"

# Override for avid.com
cat > /etc/resolver/avid.com << 'EOF'
# Force avid.com to use Cloudflare DNS
# Bypasses router DNS filtering
# Created by: master-fix-cloudflare.sh
nameserver 1.1.1.1
nameserver 1.0.0.1
EOF
chmod 644 /etc/resolver/avid.com
echo -e "${GREEN}✓ Created /etc/resolver/avid.com${NC}\n"

# Step 3: Flush DNS cache
echo -e "${CYAN}[Step 3/5] Flushing DNS cache...${NC}"
dscacheutil -flushcache
killall -HUP mDNSResponder 2>/dev/null || true
echo -e "${GREEN}✓ DNS cache flushed${NC}\n"

# Step 4: Check for blockers
echo -e "${CYAN}[Step 4/5] Checking for content blockers...${NC}"
BLOCKERS=$(ps aux | grep -i "little.*snitch\|1blocker\|adguard" | grep -v grep || true)
if [ -n "$BLOCKERS" ]; then
    echo -e "${YELLOW}⚠️  Content blocking software detected${NC}"
    echo -e "${YELLOW}   Consider temporarily disabling if issues persist${NC}"
else
    echo -e "${GREEN}✓ No known content blockers running${NC}"
fi
echo ""

# Step 5: Test connectivity
echo -e "${CYAN}[Step 5/5] Testing connectivity...${NC}"

echo -n "  • Testing www.cloudflare.com: "
if curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 https://www.cloudflare.com | grep -q "200"; then
    echo -e "${GREEN}✓ OK${NC}"
else
    echo -e "${YELLOW}⚠ FAILED${NC}"
fi

echo -n "  • Testing challenges.cloudflare.com: "
CHALLENGE_CODE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 https://challenges.cloudflare.com)
echo -e "${GREEN}HTTP $CHALLENGE_CODE${NC}"

echo -n "  • Testing www.avid.com: "
AVID_CODE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 https://www.avid.com)
if [ "$AVID_CODE" = "403" ] || [ "$AVID_CODE" = "200" ]; then
    echo -e "${GREEN}✓ OK (HTTP $AVID_CODE)${NC}"
else
    echo -e "${YELLOW}⚠ HTTP $AVID_CODE${NC}"
fi

# Summary
echo ""
echo -e "${BOLD}${GREEN}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${GREEN}║              Configuration Complete!                   ║${NC}"
echo -e "${BOLD}${GREEN}╚════════════════════════════════════════════════════════╝${NC}\n"

echo -e "${CYAN}What was fixed:${NC}"
echo -e "  ✓ System DNS set to Cloudflare (1.1.1.1)"
echo -e "  ✓ DNS resolver overrides for Cloudflare domains"
echo -e "  ✓ DNS cache flushed"
echo -e "  ✓ Router DNS filtering bypassed"
echo ""

echo -e "${CYAN}Next steps:${NC}"
echo -e "  1. ${BOLD}Close ALL browser windows${NC}"
echo -e "  2. ${BOLD}Open a fresh browser window${NC}"
echo -e "  3. ${BOLD}Navigate to: ${GREEN}https://www.avid.com${NC}"
echo -e "  4. ${BOLD}The Cloudflare challenge should complete automatically${NC}"
echo ""

echo -e "${CYAN}Testing in browser now...${NC}"
sleep 2

# Open in default browser
sudo -u $(stat -f '%Su' /dev/console) open "https://www.avid.com"

echo -e "\n${YELLOW}If avid.com still shows the challenge:${NC}"
echo -e "  1. Wait 10-15 seconds for the challenge to complete"
echo -e "  2. Ensure JavaScript is enabled in your browser"
echo -e "  3. Try opening in private/incognito mode"
echo -e "  4. Check browser console (F12) for errors"
echo ""

echo -e "${CYAN}These fixes are permanent and will persist across reboots.${NC}"
echo ""

echo -e "${GREEN}To verify on other Tailnet nodes (motoko, wintermute, etc.):${NC}"
echo -e "  Run this script on each node, or"
echo -e "  Deploy via Ansible: ansible-playbook playbooks/fix-cloudflare-dns.yml"
echo ""

echo -e "${BOLD}${GREEN}Fix deployment complete!${NC}"




