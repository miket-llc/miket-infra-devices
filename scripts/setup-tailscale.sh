#!/bin/bash
# ============================================================================
# Tailscale Device Setup Script
# ============================================================================
# This script configures Tailscale on devices with appropriate tags
# as defined in the miket-infra repository's Terraform configuration
#
# Usage: ./setup-tailscale.sh [device-name]
# ============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Detect hostname if not provided
DEVICE_NAME="${1:-$(hostname)}"

echo -e "${GREEN}Setting up Tailscale for: ${DEVICE_NAME}${NC}"

# Define device tags based on hostname
# These must match the tags defined in miket-infra/infra/tailscale/entra-prod/devices.tf
case "$DEVICE_NAME" in
    motoko)
        TAGS="tag:server,tag:linux,tag:ansible"
        ADVERTISE_ROUTES="--advertise-routes=192.168.1.0/24"  # Local network
        SSH_ENABLED="--ssh"
        ;;
    armitage)
        echo -e "${YELLOW}Note: Armitage is Windows. Use setup-tailscale.ps1 instead${NC}"
        exit 1
        ;;
    wintermute)
        echo -e "${YELLOW}Note: Wintermute is Windows. Use setup-tailscale.ps1 instead${NC}"
        exit 1
        ;;
    count-zero)
        TAGS="tag:workstation,tag:macos"
        ADVERTISE_ROUTES=""
        SSH_ENABLED="--ssh"
        ;;
    *)
        echo -e "${RED}Unknown device: $DEVICE_NAME${NC}"
        echo "Please add device configuration to this script"
        exit 1
        ;;
esac

# Check if Tailscale is installed
if ! command -v tailscale &> /dev/null; then
    echo -e "${RED}Tailscale is not installed${NC}"
    echo "Installing Tailscale..."
    
    # Detect OS and install
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux installation
        curl -fsSL https://tailscale.com/install.sh | sh
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS installation
        if command -v brew &> /dev/null; then
            brew install tailscale
        else
            echo -e "${RED}Please install Tailscale from: https://tailscale.com/download/mac${NC}"
            exit 1
        fi
    else
        echo -e "${RED}Unsupported OS: $OSTYPE${NC}"
        exit 1
    fi
fi

# Check current Tailscale status
if tailscale status &> /dev/null; then
    echo -e "${YELLOW}Tailscale is already connected${NC}"
    CURRENT_TAGS=$(tailscale status --json | jq -r '.Self.Tags[]?' 2>/dev/null | tr '\n' ',' | sed 's/,$//')
    echo "Current tags: ${CURRENT_TAGS:-none}"
    
    read -p "Reconfigure with new tags? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Keeping current configuration"
        exit 0
    fi
fi

# Bring up Tailscale with appropriate configuration
echo -e "${GREEN}Configuring Tailscale...${NC}"
echo "Tags: $TAGS"
echo "SSH: $([ -n "$SSH_ENABLED" ] && echo "Enabled" || echo "Disabled")"
echo "Routes: ${ADVERTISE_ROUTES:-none}"

# Build tailscale up command
TAILSCALE_CMD="sudo tailscale up"
TAILSCALE_CMD="$TAILSCALE_CMD --advertise-tags=$TAGS"
[ -n "$SSH_ENABLED" ] && TAILSCALE_CMD="$TAILSCALE_CMD $SSH_ENABLED"
[ -n "$ADVERTISE_ROUTES" ] && TAILSCALE_CMD="$TAILSCALE_CMD $ADVERTISE_ROUTES"

echo "Running: $TAILSCALE_CMD"
eval $TAILSCALE_CMD

# Verify connection
if tailscale status &> /dev/null; then
    echo -e "${GREEN}✅ Tailscale configured successfully!${NC}"
    echo
    tailscale status
else
    echo -e "${RED}❌ Failed to configure Tailscale${NC}"
    exit 1
fi

# Special setup for Ansible control node (motoko)
if [[ "$DEVICE_NAME" == "motoko" ]]; then
    echo -e "${GREEN}Setting up Ansible for managing other devices...${NC}"
    
    # Install Ansible if not present
    if ! command -v ansible &> /dev/null; then
        echo "Installing Ansible..."
        if [[ "$OSTYPE" == "linux-gnu"* ]]; then
            sudo apt update
            sudo apt install -y ansible python3-pip
            pip3 install pywinrm  # For Windows management
        fi
    fi
    
    echo -e "${GREEN}✅ Motoko is ready as Ansible control node${NC}"
    echo "You can now manage other devices using:"
    echo "  ansible-playbook -i ~/miket-infra-devices/ansible/inventory/hosts.yml playbooks/site.yml"
fi

echo
echo -e "${GREEN}Setup complete!${NC}"
echo "Device $DEVICE_NAME is now connected to the Tailnet with tags: $TAGS"