#!/bin/bash
# Copyright (c) 2025 MikeT LLC. All rights reserved.

# ============================================================================
# macOS Bootstrap Script for Tailscale + Remote Management
# ============================================================================
# Purpose: Complete macOS device onboarding for miket-infra-devices
# Usage: curl -fsSL https://raw.githubusercontent.com/miket-llc/miket-infra-devices/main/scripts/bootstrap-macos.sh | bash
# Or: ./scripts/bootstrap-macos.sh
# ============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
DEVICE_NAME="${1:-$(hostname -s)}"
TAILNET_DOMAIN="pangolin-vega.ts.net"  # Will be auto-detected from Tailscale

echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   macOS Device Bootstrap - miket-infra-devices              ║${NC}"
echo -e "${GREEN}║   Device: ${DEVICE_NAME}${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}\n"

# Check if running as root (should not be)
if [ "$EUID" -eq 0 ]; then 
   echo -e "${RED}ERROR: Do not run this script as root (will use sudo when needed)${NC}"
   exit 1
fi

# ============================================================================
# Step 1: Install Tailscale
# ============================================================================
echo -e "${CYAN}[1/6] Checking Tailscale installation...${NC}"

if ! command -v tailscale &> /dev/null; then
    echo -e "${YELLOW}Tailscale not found. Installing via Homebrew...${NC}"
    
    # Check Homebrew
    if ! command -v brew &> /dev/null; then
        echo -e "${RED}Homebrew not installed. Installing Homebrew first...${NC}"
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        
        # Add Homebrew to PATH for M1/M2 Macs
        if [[ $(uname -m) == 'arm64' ]]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        fi
    fi
    
    # Install Tailscale
    brew install tailscale
    
    # Start Tailscale service
    sudo brew services start tailscale
    sleep 3
    
    echo -e "${GREEN}✅ Tailscale installed${NC}"
else
    echo -e "${GREEN}✅ Tailscale already installed${NC}"
    
    # Ensure service is running
    if ! sudo brew services list | grep tailscale | grep -q started; then
        sudo brew services start tailscale
        sleep 3
    fi
fi

# ============================================================================
# Step 2: Configure Tailscale with MagicDNS and SSH
# ============================================================================
echo -e "\n${CYAN}[2/6] Configuring Tailscale...${NC}"

# Determine tags based on device name
case "$DEVICE_NAME" in
    count-zero)
        TAGS="tag:workstation,tag:macos"
        ;;
    *)
        TAGS="tag:workstation,tag:macos"
        echo -e "${YELLOW}Using default tags for unknown device${NC}"
        ;;
esac

# Check if already connected
if tailscale status &> /dev/null; then
    echo -e "${YELLOW}Tailscale already connected${NC}"
    CURRENT_DNS=$(tailscale status --json | jq -r '.Self.DNSName // "none"')
    echo "Current DNS name: $CURRENT_DNS"
    
    read -p "Reconfigure Tailscale? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Keeping current configuration"
    else
        echo "Reconfiguring..."
        sudo tailscale up --accept-dns --accept-routes --advertise-tags=$TAGS --ssh
    fi
else
    echo "Connecting to Tailscale..."
    sudo tailscale up --accept-dns --accept-routes --advertise-tags=$TAGS --ssh
fi

echo -e "${GREEN}✅ Tailscale configured (MagicDNS + SSH enabled)${NC}"

# ============================================================================
# Step 3: Configure macOS DNS Resolver for MagicDNS (CRITICAL for Homebrew)
# ============================================================================
echo -e "\n${CYAN}[3/6] Configuring macOS DNS resolver for MagicDNS...${NC}"

# Auto-detect tailnet domain
DETECTED_DOMAIN=$(tailscale status --json | jq -r '.MagicDNSSuffix // empty')

if [ -z "$DETECTED_DOMAIN" ]; then
    echo -e "${RED}ERROR: Could not detect MagicDNS suffix from Tailscale${NC}"
    echo -e "${YELLOW}Using default: $TAILNET_DOMAIN${NC}"
    DETECTED_DOMAIN="$TAILNET_DOMAIN"
else
    TAILNET_DOMAIN="$DETECTED_DOMAIN"
    echo "Detected tailnet domain: $TAILNET_DOMAIN"
fi

# Create resolver directory
sudo mkdir -p /etc/resolver

# Create resolver file for MagicDNS
RESOLVER_FILE="/etc/resolver/$TAILNET_DOMAIN"
echo -e "${YELLOW}Creating resolver: $RESOLVER_FILE${NC}"

sudo bash -c "cat > $RESOLVER_FILE" << EOF
# Tailscale MagicDNS Resolver
# Created by bootstrap-macos.sh
# Route all DNS queries for *.${TAILNET_DOMAIN} to Tailscale DNS
nameserver 100.100.100.100
EOF

# Flush DNS cache
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder 2>/dev/null || true

echo -e "${GREEN}✅ MagicDNS resolver configured${NC}"

# Verify DNS resolution
echo -e "\n${CYAN}Testing DNS resolution...${NC}"
if ping -c 1 motoko.${TAILNET_DOMAIN} &> /dev/null || ping -c 1 count-zero.${TAILNET_DOMAIN} &> /dev/null; then
    echo -e "${GREEN}✅ MagicDNS is working${NC}"
else
    echo -e "${YELLOW}⚠️  DNS resolution test inconclusive (some devices may be offline)${NC}"
fi

# ============================================================================
# Step 4: Enable Remote Login (SSH)
# ============================================================================
echo -e "\n${CYAN}[4/6] Enabling Remote Login (SSH)...${NC}"

REMOTE_LOGIN_STATUS=$(sudo systemsetup -getremotelogin)
if [[ "$REMOTE_LOGIN_STATUS" == *"On"* ]]; then
    echo -e "${GREEN}✅ Remote Login already enabled${NC}"
else
    echo "Enabling Remote Login..."
    sudo systemsetup -setremotelogin on
    sleep 2
    echo -e "${GREEN}✅ Remote Login enabled${NC}"
fi

# ============================================================================
# Step 5: Configure SSH for Remote User
# ============================================================================
echo -e "\n${CYAN}[5/6] Configuring SSH...${NC}"

# Create .ssh directory
mkdir -p ~/.ssh
chmod 700 ~/.ssh

# Create authorized_keys if doesn't exist
if [ ! -f ~/.ssh/authorized_keys ]; then
    touch ~/.ssh/authorized_keys
    chmod 600 ~/.ssh/authorized_keys
    echo -e "${GREEN}✅ Created authorized_keys file${NC}"
    echo -e "${YELLOW}⚠️  Add SSH public keys from other devices for passwordless access${NC}"
else
    echo -e "${GREEN}✅ authorized_keys file exists${NC}"
fi

# Ensure user is in admin group for sudo
if groups | grep -q admin; then
    echo -e "${GREEN}✅ User is in admin group${NC}"
else
    echo -e "${YELLOW}Adding user to admin group...${NC}"
    sudo dseditgroup -o edit -a $(whoami) -t user admin
    echo -e "${GREEN}✅ User added to admin group${NC}"
fi

# ============================================================================
# Step 6: Install Remote Desktop Client (Optional)
# ============================================================================
echo -e "\n${CYAN}[6/6] Checking Microsoft Remote Desktop...${NC}"

if [ -d "/Applications/Microsoft Remote Desktop.app" ]; then
    echo -e "${GREEN}✅ Microsoft Remote Desktop installed${NC}"
else
    echo -e "${YELLOW}⚠️  Microsoft Remote Desktop NOT installed${NC}"
    echo -e "   Install from Mac App Store: https://apps.apple.com/us/app/microsoft-remote-desktop/id1295203466"
    echo -e "   Or run: brew install --cask microsoft-remote-desktop"
fi

# ============================================================================
# Final Verification
# ============================================================================
echo -e "\n${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   Bootstrap Complete - Verification                          ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}\n"

echo -e "${CYAN}Tailscale Status:${NC}"
tailscale status | head -5

echo -e "\n${CYAN}MagicDNS Configuration:${NC}"
echo "Resolver file: $RESOLVER_FILE"
cat "$RESOLVER_FILE" 2>/dev/null || echo "File not readable"

echo -e "\n${CYAN}SSH Status:${NC}"
sudo systemsetup -getremotelogin

echo -e "\n${CYAN}Next Steps:${NC}"
echo "1. Test MagicDNS: ping motoko.$TAILNET_DOMAIN"
echo "2. Add this device to miket-infra-devices Ansible inventory if not already present"
echo "3. Test Ansible: ansible count-zero -m ping"
echo "4. Install Microsoft Remote Desktop from Mac App Store (if needed for RDP to Windows)"

echo -e "\n${GREEN}✅ macOS device ready for management via Tailscale${NC}"

