#!/bin/bash
# Copyright (c) 2025 MikeT LLC. All rights reserved.

# Setup remote management on count-zero (macOS)
# Run this locally on count-zero

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}=== Setting up remote management on count-zero ===${NC}\n"

# Check if running as root for some commands
if [ "$EUID" -ne 0 ]; then 
    echo -e "${YELLOW}Note: This script will prompt for sudo password for some commands${NC}\n"
fi

# 1. Enable Remote Login (SSH)
echo -e "${GREEN}[1/4] Enabling Remote Login (SSH)...${NC}"
sudo systemsetup -setremotelogin on
STATUS=$(sudo systemsetup -getremotelogin)
if [[ "$STATUS" == *"On"* ]]; then
    echo -e "  ✅ Remote Login enabled"
else
    echo -e "  ${RED}❌ Failed to enable Remote Login${NC}"
    exit 1
fi

# 2. Enable Tailscale SSH and MagicDNS
echo -e "\n${GREEN}[2/4] Configuring Tailscale...${NC}"
if ! command -v tailscale &> /dev/null; then
    echo -e "  ${RED}❌ Tailscale not installed${NC}"
    echo -e "  Install from: https://tailscale.com/download/mac"
    exit 1
fi

tailscale up --accept-dns --advertise-tags=tag:workstation,tag:macos --ssh
if [ $? -eq 0 ]; then
    echo -e "  ✅ Tailscale configured with SSH and MagicDNS"
else
    echo -e "  ${YELLOW}⚠️  Tailscale configuration may need manual completion${NC}"
fi

# 3. Configure SSH for mdt user
echo -e "\n${GREEN}[3/4] Configuring SSH for mdt user...${NC}"
mkdir -p ~/.ssh
chmod 700 ~/.ssh

# Check if user is in admin group
if groups | grep -q admin; then
    echo -e "  ✅ User is in admin group"
else
    echo -e "  ${YELLOW}Adding user to admin group...${NC}"
    sudo dseditgroup -o edit -a $(whoami) -t user admin
    echo -e "  ✅ User added to admin group"
fi

# Create authorized_keys if it doesn't exist
if [ ! -f ~/.ssh/authorized_keys ]; then
    touch ~/.ssh/authorized_keys
    chmod 600 ~/.ssh/authorized_keys
    echo -e "  ✅ Created authorized_keys file"
    echo -e "  ${YELLOW}⚠️  You'll need to add SSH public keys from other machines${NC}"
fi

# 4. Verify setup
echo -e "\n${GREEN}[4/4] Verifying setup...${NC}"

# Check SSH is running
if sudo launchctl list | grep -q com.openssh.sshd; then
    echo -e "  ✅ SSH service is running"
else
    echo -e "  ${RED}❌ SSH service not running${NC}"
fi

# Check Tailscale
TAILSCALE_STATUS=$(tailscale status --json 2>/dev/null | python3 -c "import sys, json; data=json.load(sys.stdin); print(f\"{data['Self']['HostName']} - DNS: {data['Self'].get('DNS', 'null')}\")" 2>/dev/null)
if [ $? -eq 0 ]; then
    echo -e "  ✅ Tailscale: $TAILSCALE_STATUS"
else
    echo -e "  ${YELLOW}⚠️  Could not verify Tailscale status${NC}"
fi

# Test hostname resolution
if ping -c 1 motoko.pangolin-vega.ts.net >/dev/null 2>&1 || ping -c 1 motoko >/dev/null 2>&1; then
    echo -e "  ✅ Can resolve motoko hostname"
else
    echo -e "  ${YELLOW}⚠️  Cannot resolve motoko hostname yet${NC}"
fi

# Display connection info
echo -e "\n${GREEN}=== Setup Complete ===${NC}"
echo -e "\nTo connect from motoko, use:"
echo -e "  ${YELLOW}ssh mdt@count-zero.pangolin-vega.ts.net${NC}"
echo -e "  ${YELLOW}tailscale ssh mdt@count-zero${NC}"
echo -e "\nTo test Ansible connectivity from motoko:"
echo -e "  ${YELLOW}ansible -i ansible/inventory/hosts.yml count-zero -m ping${NC}"
echo -e "\n${YELLOW}Note: You may need to add motoko's SSH public key to ~/.ssh/authorized_keys${NC}"
echo -e "From motoko, run: ${YELLOW}cat ~/.ssh/id_*.pub${NC}"


