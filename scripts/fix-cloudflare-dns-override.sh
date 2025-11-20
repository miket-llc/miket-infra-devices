#!/bin/bash

# Fix Cloudflare Challenge by Overriding DNS for Cloudflare domains
# This creates /etc/resolver entries to bypass router DNS filtering

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}Cloudflare DNS Override Fix${NC}"
echo -e "${CYAN}========================================${NC}\n"

# Check if running as root or with sudo
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}This script requires sudo access${NC}"
    echo -e "${YELLOW}Please run with: sudo $0${NC}"
    exit 1
fi

# Create /etc/resolver directory if it doesn't exist
mkdir -p /etc/resolver

# Create resolver for cloudflare.com domains
echo -e "${GREEN}Creating DNS override for cloudflare.com...${NC}"
cat > /etc/resolver/cloudflare.com << 'EOF'
# Force Cloudflare domains to use Cloudflare DNS
# This bypasses router DNS filtering
nameserver 1.1.1.1
nameserver 1.0.0.1
EOF

echo -e "${GREEN}✓ Created /etc/resolver/cloudflare.com${NC}"

# Create resolver for avid.com
echo -e "${GREEN}Creating DNS override for avid.com...${NC}"
cat > /etc/resolver/avid.com << 'EOF'
# Force avid.com to use Cloudflare DNS
# This bypasses router DNS filtering
nameserver 1.1.1.1
nameserver 1.0.0.1
EOF

echo -e "${GREEN}✓ Created /etc/resolver/avid.com${NC}"

# Set proper permissions
chmod 644 /etc/resolver/cloudflare.com
chmod 644 /etc/resolver/avid.com

# Flush DNS cache
echo -e "\n${GREEN}Flushing DNS cache...${NC}"
dscacheutil -flushcache
killall -HUP mDNSResponder 2>/dev/null || true
echo -e "${GREEN}✓ DNS cache flushed${NC}"

# Test DNS resolution
echo -e "\n${GREEN}Testing DNS resolution...${NC}"
echo -n "challenges.cloudflare.com: "
dig +short challenges.cloudflare.com @1.1.1.1 | head -1

echo -n "www.avid.com: "
dig +short www.avid.com @1.1.1.1 | head -1

# Test connectivity
echo -e "\n${GREEN}Testing connectivity...${NC}"
echo -n "www.cloudflare.com: "
if curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 https://www.cloudflare.com | grep -q "200"; then
    echo -e "${GREEN}OK${NC}"
else
    echo -e "${RED}FAILED${NC}"
fi

echo -n "www.avid.com: "
AVID_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 https://www.avid.com)
if [ "$AVID_RESPONSE" = "403" ] || [ "$AVID_RESPONSE" = "200" ]; then
    echo -e "${GREEN}OK (HTTP $AVID_RESPONSE - Cloudflare challenge)${NC}"
else
    echo -e "${YELLOW}HTTP $AVID_RESPONSE${NC}"
fi

echo ""
echo -e "${CYAN}========================================${NC}"
echo -e "${GREEN}DNS Override Applied Successfully!${NC}"
echo -e "${CYAN}========================================${NC}"
echo -e "Cloudflare and avid.com now use Cloudflare DNS (1.1.1.1)"
echo -e "This bypasses any router DNS filtering."
echo ""
echo -e "${GREEN}Next steps:${NC}"
echo -e "1. Close all browser windows"
echo -e "2. Open a new browser window"
echo -e "3. Visit ${GREEN}https://www.avid.com${NC}"
echo -e "4. The Cloudflare challenge should now complete"
echo ""
echo -e "${YELLOW}To remove this override later:${NC}"
echo -e "  sudo rm /etc/resolver/cloudflare.com /etc/resolver/avid.com"




