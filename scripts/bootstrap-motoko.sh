#!/bin/bash
# Copyright (c) 2025 MikeT LLC. All rights reserved.

# ============================================================================
# Motoko Ansible Control Node Bootstrap Script
# ============================================================================
# This script sets up motoko as the Ansible control node for managing
# all infrastructure devices over the Tailscale network.
#
# Usage: Run this script on motoko after cloning miket-infra-devices
# ============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

REPO_DIR="${HOME}/miket-infra-devices"
REPO_URL="https://github.com/miket-llc/miket-infra-devices.git"

echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Motoko Ansible Control Node Bootstrap                  ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
echo

# Step 1: Clone repository if needed
if [ ! -d "$REPO_DIR" ]; then
    echo -e "${GREEN}[1/5] Cloning miket-infra-devices repository...${NC}"
    git clone "$REPO_URL" "$REPO_DIR"
else
    echo -e "${GREEN}[1/5] Repository already exists, updating...${NC}"
    cd "$REPO_DIR"
    git pull
fi

cd "$REPO_DIR"

# Step 2: Configure Tailscale
echo -e "${GREEN}[2/5] Configuring Tailscale...${NC}"
chmod +x scripts/setup-tailscale.sh
./scripts/setup-tailscale.sh motoko

# Step 3: Verify Tailscale connection
echo -e "${GREEN}[3/5] Verifying Tailscale connection...${NC}"
if ! tailscale status &> /dev/null; then
    echo -e "${RED}❌ Tailscale is not connected. Please run: sudo tailscale up${NC}"
    exit 1
fi

TAILSCALE_TAGS=$(tailscale status --json | jq -r '.Self.Tags[]?' 2>/dev/null | tr '\n' ',' | sed 's/,$//')
echo -e "${GREEN}✅ Tailscale connected with tags: ${TAILSCALE_TAGS}${NC}"

# Verify ansible tag is present
if ! echo "$TAILSCALE_TAGS" | grep -q "tag:ansible"; then
    echo -e "${YELLOW}⚠️  Warning: tag:ansible not found. Re-running setup...${NC}"
    ./scripts/setup-tailscale.sh motoko
fi

# Step 4: Install Ansible and dependencies
echo -e "${GREEN}[4/5] Installing Ansible and dependencies...${NC}"

if ! command -v ansible &> /dev/null; then
    echo "Installing Ansible..."
    sudo apt update
    sudo apt install -y ansible python3-pip python3-jmespath
    pip3 install pywinrm  # For Windows management
else
    echo -e "${GREEN}✅ Ansible already installed${NC}"
fi

# Verify Ansible installation
ANSIBLE_VERSION=$(ansible --version | head -n1)
echo -e "${GREEN}✅ ${ANSIBLE_VERSION}${NC}"

# Step 5: Test connectivity
echo -e "${GREEN}[5/5] Testing connectivity to devices...${NC}"
echo

# Test SSH to Linux/Mac devices
echo -e "${BLUE}Testing SSH to Linux/Mac devices...${NC}"
if tailscale ssh mdt@count-zero.pangolin-vega.ts.net "hostname" &> /dev/null; then
    echo -e "${GREEN}✅ Can SSH to count-zero${NC}"
else
    echo -e "${YELLOW}⚠️  Cannot SSH to count-zero (may be offline or not configured)${NC}"
fi

# Test Ansible ping
echo -e "${BLUE}Testing Ansible connectivity...${NC}"
cd "$REPO_DIR"

# Test Linux devices
if ansible linux -i ansible/inventory/hosts.yml -m ping &> /dev/null; then
    echo -e "${GREEN}✅ Linux devices reachable via Ansible${NC}"
else
    echo -e "${YELLOW}⚠️  Linux devices not reachable (may be offline)${NC}"
fi

# Test macOS devices
if ansible macos -i ansible/inventory/hosts.yml -m ping &> /dev/null; then
    echo -e "${GREEN}✅ macOS devices reachable via Ansible${NC}"
else
    echo -e "${YELLOW}⚠️  macOS devices not reachable (may be offline)${NC}"
fi

# Test Windows devices (WinRM)
if ansible windows -i ansible/inventory/hosts.yml -m win_ping &> /dev/null; then
    echo -e "${GREEN}✅ Windows devices reachable via Ansible WinRM${NC}"
else
    echo -e "${YELLOW}⚠️  Windows devices not reachable (WinRM may not be configured)${NC}"
fi

echo
echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Setup Complete!                                         ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
echo
echo -e "${GREEN}Motoko is now configured as the Ansible control node.${NC}"
echo
echo -e "${BLUE}Quick Start:${NC}"
echo "  cd $REPO_DIR"
echo "  ansible all -i ansible/inventory/hosts.yml -m ping"
echo
echo -e "${BLUE}Run a playbook:${NC}"
echo "  ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/standardize-users.yml"
echo
echo -e "${BLUE}Documentation:${NC}"
echo "  See: docs/runbooks/motoko-ansible-setup.md"
echo

