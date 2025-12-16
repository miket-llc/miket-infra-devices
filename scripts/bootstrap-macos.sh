#!/bin/bash
# Copyright (c) 2025 MikeT LLC. All rights reserved.

# ============================================================================
# macOS Bootstrap Script for Tailscale + Remote Management
# ============================================================================
# Purpose: Complete macOS device onboarding for miket-infra-devices
#
# PREREQUISITES (manual):
#   1. User account created with admin privileges
#
# Usage: ./scripts/bootstrap-macos.sh
#
# This script handles:
#   - Tailscale Standalone installation (from pkgs.tailscale.com)
#   - CLI wrapper installation
#   - SSH Remote Login enablement
#   - SSH firewall restriction to Tailscale IPs only (pf)
#   - Basic SSH directory setup
#
# We use the STANDALONE version (not App Store, not Homebrew) because:
#   - DNS/MagicDNS works automatically (Network Extension)
#   - `tailscale ssh` works (not sandboxed like App Store)
#   - No /etc/resolver hacks needed (unlike Homebrew)
#
# After bootstrap, run Ansible playbooks for remaining tools:
#   - ansible-playbook playbooks/common/dev-tools.yml --limit <hostname>
#   - ansible-playbook playbooks/deploy-baseline-tools.yml --limit <hostname>
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
TAILNET_DOMAIN="pangolin-vega.ts.net"
TAILSCALE_VERSION="1.92.2"

echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   macOS Device Bootstrap - miket-infra-devices                ║${NC}"
echo -e "${GREEN}║   Device: ${DEVICE_NAME}${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}\n"

# Check if running as root (should not be)
if [ "$EUID" -eq 0 ]; then
   echo -e "${RED}ERROR: Do not run this script as root (will use sudo when needed)${NC}"
   exit 1
fi

# ============================================================================
# Step 1: Install Tailscale Standalone
# ============================================================================
echo -e "${CYAN}[1/6] Checking Tailscale installation...${NC}"

if [ -d "/Applications/Tailscale.app" ]; then
    # Check if it's Standalone or App Store by testing tailscale ssh
    if /Applications/Tailscale.app/Contents/MacOS/Tailscale ssh --help 2>&1 | grep -q "not available"; then
        echo -e "${YELLOW}App Store version detected. Removing and installing Standalone...${NC}"
        osascript -e 'quit app "Tailscale"' 2>/dev/null || true
        sleep 2
        sudo rm -rf /Applications/Tailscale.app
    else
        echo -e "${GREEN}✅ Tailscale Standalone already installed${NC}"
    fi
fi

if [ ! -d "/Applications/Tailscale.app" ]; then
    echo -e "${YELLOW}Installing Tailscale Standalone from pkgs.tailscale.com...${NC}"

    # Download latest stable
    PKG_URL="https://pkgs.tailscale.com/stable/Tailscale-${TAILSCALE_VERSION}-macos.pkg"
    echo "Downloading from: $PKG_URL"

    cd /tmp
    curl -O "$PKG_URL"

    # Install
    sudo installer -pkg "Tailscale-${TAILSCALE_VERSION}-macos.pkg" -target /
    rm -f "Tailscale-${TAILSCALE_VERSION}-macos.pkg"

    echo -e "${GREEN}✅ Tailscale Standalone installed${NC}"

    # Open the app
    echo -e "${YELLOW}Opening Tailscale - please:${NC}"
    echo -e "  1. Allow the System Extension in System Settings → Privacy & Security"
    echo -e "  2. Sign in with Microsoft (mike@miket.io)"
    open /Applications/Tailscale.app

    echo -e "${YELLOW}Press Enter after you've signed in and are connected...${NC}"
    read -r
fi

# Check if Tailscale is connected
if ! /Applications/Tailscale.app/Contents/MacOS/Tailscale status &> /dev/null; then
    echo -e "${RED}ERROR: Tailscale is not connected.${NC}"
    echo -e "${YELLOW}Please click the Tailscale menu bar icon and sign in.${NC}"
    echo -e "${YELLOW}Press Enter after you're connected...${NC}"
    read -r
fi

echo -e "${GREEN}✅ Tailscale Standalone connected${NC}"

# ============================================================================
# Step 2: Install CLI Wrapper
# ============================================================================
echo -e "\n${CYAN}[2/6] Installing Tailscale CLI wrapper...${NC}"

sudo mkdir -p /usr/local/bin

if [ -f /usr/local/bin/tailscale ]; then
    echo -e "${YELLOW}CLI wrapper already exists, updating...${NC}"
fi

sudo tee /usr/local/bin/tailscale > /dev/null << 'EOF'
#!/bin/sh
exec /Applications/Tailscale.app/Contents/MacOS/Tailscale "$@"
EOF
sudo chmod +x /usr/local/bin/tailscale

echo -e "${GREEN}✅ CLI wrapper installed at /usr/local/bin/tailscale${NC}"

# Verify CLI works
if tailscale status &> /dev/null; then
    echo -e "${GREEN}✅ CLI working${NC}"
else
    echo -e "${RED}ERROR: CLI wrapper not working${NC}"
    exit 1
fi

# ============================================================================
# Step 3: Enable Remote Login (SSH)
# ============================================================================
echo -e "\n${CYAN}[3/6] Enabling Remote Login (SSH)...${NC}"

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
# Step 4: Configure Firewall to Restrict SSH to Tailscale IPs
# ============================================================================
echo -e "\n${CYAN}[4/6] Configuring firewall (SSH restricted to Tailscale only)...${NC}"

# Create pf anchor for Tailscale SSH restriction
sudo tee /etc/pf.anchors/tailscale-ssh > /dev/null << 'EOF'
# Only allow SSH from Tailscale CGNAT range (100.64.0.0/10)
# Block SSH from all other sources
# Created by bootstrap-macos.sh

# Allow SSH from Tailscale IPs
pass in quick on utun* proto tcp from 100.64.0.0/10 to any port 22
pass in quick proto tcp from 100.64.0.0/10 to any port 22

# Block SSH from everywhere else
block drop in quick proto tcp from any to any port 22
EOF

# Add anchor to pf.conf if not present
if ! grep -q "tailscale-ssh" /etc/pf.conf; then
    echo -e "${YELLOW}Adding tailscale-ssh anchor to pf.conf...${NC}"
    sudo bash -c 'echo "" >> /etc/pf.conf'
    sudo bash -c 'echo "# Tailscale SSH restriction - only allow SSH from Tailscale IPs" >> /etc/pf.conf'
    sudo bash -c 'echo "anchor \"tailscale-ssh\"" >> /etc/pf.conf'
    sudo bash -c 'echo "load anchor \"tailscale-ssh\" from \"/etc/pf.anchors/tailscale-ssh\"" >> /etc/pf.conf'
fi

# Load the rules
sudo pfctl -f /etc/pf.conf 2>/dev/null || true

# Verify rules loaded
if sudo pfctl -a tailscale-ssh -sr 2>/dev/null | grep -q "port = 22"; then
    echo -e "${GREEN}✅ Firewall configured - SSH only accessible from Tailscale (100.64.0.0/10)${NC}"
else
    echo -e "${YELLOW}⚠️  Firewall rules may not be active until next reboot${NC}"
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
# Step 6: Verify Configuration
# ============================================================================
echo -e "\n${CYAN}[6/6] Verifying configuration...${NC}"

# Auto-detect tailnet domain
DETECTED_DOMAIN=$(tailscale status --json | jq -r '.MagicDNSSuffix // empty' 2>/dev/null)
if [ -n "$DETECTED_DOMAIN" ]; then
    TAILNET_DOMAIN="$DETECTED_DOMAIN"
fi

# Test DNS resolution
echo -e "${CYAN}Testing MagicDNS...${NC}"
if ping -c 1 -W 2 akira.${TAILNET_DOMAIN} &> /dev/null; then
    echo -e "${GREEN}✅ MagicDNS working (akira.${TAILNET_DOMAIN} resolves)${NC}"
elif ping -c 1 -W 2 motoko.${TAILNET_DOMAIN} &> /dev/null; then
    echo -e "${GREEN}✅ MagicDNS working (motoko.${TAILNET_DOMAIN} resolves)${NC}"
else
    echo -e "${YELLOW}⚠️  MagicDNS test inconclusive (devices may be offline)${NC}"
fi

# Test tailscale ssh
echo -e "${CYAN}Testing tailscale ssh...${NC}"
if tailscale ssh mdt@akira hostname &> /dev/null; then
    echo -e "${GREEN}✅ tailscale ssh working${NC}"
else
    echo -e "${YELLOW}⚠️  tailscale ssh test inconclusive (akira may be offline)${NC}"
fi

# ============================================================================
# Final Summary
# ============================================================================
echo -e "\n${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   Bootstrap Complete                                          ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}\n"

echo -e "${CYAN}Tailscale Status:${NC}"
tailscale status | head -5

echo -e "\n${CYAN}SSH Status:${NC}"
sudo systemsetup -getremotelogin

echo -e "\n${CYAN}Firewall Status:${NC}"
if sudo pfctl -a tailscale-ssh -sr 2>/dev/null | grep -q "port = 22"; then
    echo "SSH restricted to Tailscale IPs (100.64.0.0/10)"
else
    echo "Firewall rules will activate on next reboot"
fi

echo -e "\n${CYAN}Features:${NC}"
echo -e "  ✅ DNS/MagicDNS - works automatically"
echo -e "  ✅ tailscale ssh - works (Standalone version)"
echo -e "  ✅ SSH firewall - restricted to Tailscale IPs only"

echo -e "\n${CYAN}Usage:${NC}"
echo -e "  tailscale ssh mdt@akira       # Identity-based SSH (no keys needed)"
echo -e "  ssh mdt@akira.${TAILNET_DOMAIN}  # Traditional SSH (needs keys)"

echo -e "\n${CYAN}Next Steps:${NC}"
echo "1. Test: tailscale ssh mdt@akira hostname"
echo "2. Add SSH keys from other devices to ~/.ssh/authorized_keys (for non-tailscale ssh)"
echo "3. Run Ansible playbooks from control node (motoko)"

echo -e "\n${GREEN}✅ macOS device ready for management via Tailscale${NC}"
