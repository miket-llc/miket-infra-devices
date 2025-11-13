#!/bin/bash
# ============================================================================
# Quick fix for MagicDNS on Motoko (Linux)
# ============================================================================
# This script remediates the MagicDNS issue by re-enrolling Tailscale with
# --accept-dns flag. This is a one-time fix for devices that were enrolled
# before the setup scripts were updated.
#
# Usage: ./fix-magicdns.sh
# ============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}🔧 MagicDNS Remediation Script for Motoko${NC}"
echo -e "${CYAN}==========================================${NC}\n"

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Please run as root (use sudo)${NC}"
    exit 1
fi

# Check if Tailscale is installed
if ! command -v tailscale &> /dev/null; then
    echo -e "${RED}Tailscale is not installed. Please install Tailscale first.${NC}"
    exit 1
fi

echo -e "${GREEN}Found Tailscale: $(which tailscale)${NC}"

# Check current status
echo -e "\n${YELLOW}Checking current Tailscale status...${NC}"
if ! tailscale status &> /dev/null; then
    echo -e "${RED}Tailscale is not running. Please start Tailscale first.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Tailscale is running${NC}"

# Get current tags
CURRENT_TAGS=$(tailscale status --json | jq -r '.Self.Tags[]?' 2>/dev/null | tr '\n' ',' | sed 's/,$//')
if [ -z "$CURRENT_TAGS" ]; then
    # Fallback to default tags for motoko
    CURRENT_TAGS="tag:server,tag:linux,tag:ansible"
fi

echo -e "${CYAN}Current tags: $CURRENT_TAGS${NC}"

# Check if DNS is configured
DNS_SERVER=$(tailscale status --json | jq -r '.Self.DNS' 2>/dev/null)
if [ -n "$DNS_SERVER" ] && [ "$DNS_SERVER" != "null" ]; then
    echo -e "${CYAN}DNS server: $DNS_SERVER${NC}"
else
    echo -e "${YELLOW}⚠️  DNS not configured (this is the problem we're fixing)${NC}"
fi

# Confirm before proceeding
echo -e "\n${YELLOW}This will reset and re-enroll Tailscale with --accept-dns flag.${NC}"
read -p "Continue? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Aborted.${NC}"
    exit 0
fi

# Step 1: Reset Tailscale
echo -e "\n${GREEN}[Step 1/3] Resetting Tailscale connection...${NC}"
tailscale up --reset || echo -e "${YELLOW}Reset command completed (this is normal)${NC}"

sleep 2

# Step 2: Re-enroll with --accept-dns
echo -e "\n${GREEN}[Step 2/3] Re-enrolling with --accept-dns...${NC}"
echo -e "${CYAN}Tags: $CURRENT_TAGS${NC}"
echo -e "${CYAN}Flags: --accept-dns --accept-routes --ssh${NC}"

TAILSCALE_CMD="tailscale up"
TAILSCALE_CMD="$TAILSCALE_CMD --advertise-tags=$CURRENT_TAGS"
TAILSCALE_CMD="$TAILSCALE_CMD --accept-routes"
TAILSCALE_CMD="$TAILSCALE_CMD --accept-dns"  # CRITICAL: This fixes MagicDNS
TAILSCALE_CMD="$TAILSCALE_CMD --ssh"
TAILSCALE_CMD="$TAILSCALE_CMD --advertise-routes=192.168.1.0/24"  # Local network routes

echo -e "${CYAN}Running: $TAILSCALE_CMD${NC}"
eval $TAILSCALE_CMD

if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to re-enroll Tailscale. You may need to authenticate.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Re-enrollment initiated${NC}"

# Wait for connection to establish
echo -e "\n${YELLOW}Waiting for connection to establish...${NC}"
sleep 5

# Step 3: Verify fix
echo -e "\n${GREEN}[Step 3/3] Verifying MagicDNS fix...${NC}"
if tailscale status &> /dev/null; then
    echo -e "${GREEN}✅ Tailscale is running${NC}"
    
    # Check DNS configuration
    DNS_SERVER=$(tailscale status --json | jq -r '.Self.DNS' 2>/dev/null)
    if [ -n "$DNS_SERVER" ] && [ "$DNS_SERVER" != "null" ]; then
        echo -e "${GREEN}✅ DNS configured: $DNS_SERVER${NC}"
    else
        echo -e "${YELLOW}⚠️  DNS not yet configured. This may take a few moments.${NC}"
        echo -e "   Run 'tailscale status --json | jq .Self.DNS' to check later."
    fi
    
    # Show status
    echo -e "\n${CYAN}Tailscale Status:${NC}"
    tailscale status
    
else
    echo -e "${YELLOW}⚠️  Tailscale may need manual authentication.${NC}"
fi

echo -e "\n${GREEN}✅ Remediation complete!${NC}"
echo -e "\n${YELLOW}Next steps:${NC}"
echo -e "${CYAN}1. Test hostname resolution: ping armitage${NC}"
echo -e "${CYAN}2. Verify DNS: tailscale status --json | jq '.Self.DNS'${NC}"
echo -e "${CYAN}3. Test SSH: ssh mike@miket.io@armitage${NC}"

