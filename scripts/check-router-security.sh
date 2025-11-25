#!/bin/bash
# Copyright (c) 2025 MikeT LLC. All rights reserved.


# Check Verizon FiOS Router Security Settings
# This script helps diagnose router-level blocks of Cloudflare

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}Verizon Router Security Check${NC}"
echo -e "${CYAN}========================================${NC}\n"

# Get router IP
ROUTER_IP=$(route -n get default | grep gateway | awk '{print $2}')
echo -e "${GREEN}Router IP: $ROUTER_IP${NC}\n"

# Test router accessibility
echo -e "${GREEN}Testing router access...${NC}"
if ping -c 1 -t 1 $ROUTER_IP &>/dev/null; then
    echo -e "${GREEN}✓ Router is reachable${NC}"
else
    echo -e "${RED}✗ Router is not reachable${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}MANUAL ROUTER CONFIGURATION REQUIRED${NC}"
echo -e "${YELLOW}========================================${NC}"
echo ""
echo -e "The Cloudflare challenge is being blocked at the router level."
echo -e "You need to log into your Verizon FiOS router and disable security features.\n"
echo -e "${CYAN}Steps to fix:${NC}"
echo -e "1. Open a browser and navigate to: ${GREEN}https://myfiosgateway.com${NC}"
echo -e "2. Accept the self-signed certificate warning"
echo -e "3. Login with your router credentials (default: admin/password on router label)"
echo -e "4. Navigate to: ${GREEN}Advanced > Security${NC}"
echo -e "5. Check for and disable these features:"
echo -e "   • DNS Filtering / Content Filtering"
echo -e "   • Parental Controls"
echo -e "   • Threat Protection / Security Services"
echo -e "   • Any blocked domains list containing 'cloudflare'"
echo -e "6. Navigate to: ${GREEN}Advanced > DNS Settings${NC}"
echo -e "7. Verify DNS servers are NOT set to filtered DNS (like OpenDNS Family Shield)"
echo -e "8. Save changes and reboot router if required"
echo ""
echo -e "${CYAN}Alternative Solution (Bypass Router):${NC}"
echo -e "Use Tailscale exit node to bypass router filtering:"
echo -e "  ${GREEN}tailscale up --exit-node=<node-name>${NC}"
echo ""
echo -e "Opening router admin panel now..."
sleep 2
open "https://myfiosgateway.com"




