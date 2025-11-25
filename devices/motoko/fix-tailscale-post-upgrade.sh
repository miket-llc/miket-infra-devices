#!/bin/bash
# Copyright (c) 2025 MikeT LLC. All rights reserved.

# ============================================================================
# Fix Tailscale and DNS after Pop!_OS 24 Beta Upgrade
# ============================================================================
# This script diagnoses and fixes Tailscale/DNS issues after OS upgrade
# Usage: sudo ./fix-tailscale-post-upgrade.sh
# ============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Tailscale & DNS Fix for Pop!_OS 24 Beta Upgrade        ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
echo

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}❌ Please run as root (use sudo)${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Running with sudo privileges${NC}\n"

# ============================================================================
# Step 1: Check if Tailscale is installed
# ============================================================================
echo -e "${CYAN}[Step 1/6] Checking Tailscale installation...${NC}"

if command -v tailscale &> /dev/null; then
    TAILSCALE_PATH=$(which tailscale)
    TAILSCALE_VERSION=$(tailscale version 2>/dev/null | head -n1 || echo "unknown")
    echo -e "${GREEN}✓ Tailscale found: $TAILSCALE_PATH${NC}"
    echo -e "${GREEN}  Version: $TAILSCALE_VERSION${NC}"
else
    echo -e "${YELLOW}⚠ Tailscale not found in PATH${NC}"
    echo -e "${CYAN}Installing Tailscale...${NC}"
    curl -fsSL https://tailscale.com/install.sh | sh
    
    # Verify installation
    if command -v tailscale &> /dev/null; then
        echo -e "${GREEN}✓ Tailscale installed successfully${NC}"
    else
        echo -e "${RED}❌ Failed to install Tailscale${NC}"
        exit 1
    fi
fi

# Check for tailscaled daemon
if command -v tailscaled &> /dev/null; then
    echo -e "${GREEN}✓ tailscaled daemon found${NC}"
else
    echo -e "${RED}❌ tailscaled daemon not found${NC}"
    echo -e "${YELLOW}Reinstalling Tailscale...${NC}"
    curl -fsSL https://tailscale.com/install.sh | sh
fi

echo

# ============================================================================
# Step 2: Check systemd service status
# ============================================================================
echo -e "${CYAN}[Step 2/6] Checking Tailscale systemd service...${NC}"

if systemctl is-active --quiet tailscaled 2>/dev/null; then
    echo -e "${GREEN}✓ tailscaled service is running${NC}"
elif systemctl is-enabled --quiet tailscaled 2>/dev/null; then
    echo -e "${YELLOW}⚠ tailscaled service is enabled but not running${NC}"
    echo -e "${CYAN}Starting tailscaled service...${NC}"
    systemctl start tailscaled
    sleep 2
    if systemctl is-active --quiet tailscaled; then
        echo -e "${GREEN}✓ tailscaled service started${NC}"
    else
        echo -e "${RED}❌ Failed to start tailscaled service${NC}"
        echo -e "${YELLOW}Checking service status...${NC}"
        systemctl status tailscaled --no-pager -l || true
    fi
else
    echo -e "${YELLOW}⚠ tailscaled service not enabled${NC}"
    echo -e "${CYAN}Enabling and starting tailscaled service...${NC}"
    systemctl enable tailscaled
    systemctl start tailscaled
    sleep 2
    if systemctl is-active --quiet tailscaled; then
        echo -e "${GREEN}✓ tailscaled service enabled and started${NC}"
    else
        echo -e "${RED}❌ Failed to start tailscaled service${NC}"
        systemctl status tailscaled --no-pager -l || true
    fi
fi

echo

# ============================================================================
# Step 3: Check DNS configuration
# ============================================================================
echo -e "${CYAN}[Step 3/6] Checking DNS configuration...${NC}"

# Check resolv.conf
if [ -f /etc/resolv.conf ]; then
    echo -e "${CYAN}Current /etc/resolv.conf:${NC}"
    cat /etc/resolv.conf | sed 's/^/  /'
    echo
fi

# Check systemd-resolved if present
if systemctl is-active --quiet systemd-resolved 2>/dev/null; then
    echo -e "${CYAN}systemd-resolved status:${NC}"
    resolvectl status | head -20 | sed 's/^/  /' || true
    echo
fi

# Check NetworkManager DNS if present
if command -v nmcli &> /dev/null && systemctl is-active --quiet NetworkManager 2>/dev/null; then
    echo -e "${CYAN}NetworkManager DNS settings:${NC}"
    nmcli dev show | grep -i dns | sed 's/^/  /' || true
    echo
fi

echo

# ============================================================================
# Step 4: Check Tailscale status
# ============================================================================
echo -e "${CYAN}[Step 4/6] Checking Tailscale connection status...${NC}"

if tailscale status &> /dev/null; then
    echo -e "${GREEN}✓ Tailscale is connected${NC}"
    
    # Get current status
    STATUS_JSON=$(tailscale status --json 2>/dev/null || echo "{}")
    
    # Check DNS configuration
    DNS_SERVER=$(echo "$STATUS_JSON" | jq -r '.Self.DNS // empty' 2>/dev/null || echo "")
    if [ -n "$DNS_SERVER" ] && [ "$DNS_SERVER" != "null" ]; then
        echo -e "${GREEN}  DNS server: $DNS_SERVER${NC}"
    else
        echo -e "${YELLOW}  ⚠ DNS not configured (will fix in next step)${NC}"
    fi
    
    # Get current tags
    CURRENT_TAGS=$(echo "$STATUS_JSON" | jq -r '.Self.Tags[]?' 2>/dev/null | tr '\n' ',' | sed 's/,$//' || echo "")
    if [ -n "$CURRENT_TAGS" ]; then
        echo -e "${CYAN}  Current tags: $CURRENT_TAGS${NC}"
    fi
    
    echo
    echo -e "${CYAN}Current Tailscale status:${NC}"
    tailscale status | head -10 | sed 's/^/  /'
    echo
else
    echo -e "${YELLOW}⚠ Tailscale is not connected${NC}"
    echo -e "${CYAN}Will configure in next step...${NC}"
    echo
fi

# ============================================================================
# Step 5: Reconfigure Tailscale with proper flags
# ============================================================================
echo -e "${CYAN}[Step 5/6] Reconfiguring Tailscale...${NC}"

# Motoko-specific configuration
TAGS="tag:server,tag:linux,tag:ansible"
ADVERTISE_ROUTES="--advertise-routes=192.168.1.0/24"
SSH_ENABLED="--ssh"
EXIT_NODE="--advertise-exit-node"

echo -e "${CYAN}Configuration:${NC}"
echo -e "  Tags: $TAGS"
echo -e "  Routes: $ADVERTISE_ROUTES"
echo -e "  SSH: Enabled"
echo -e "  Exit Node: Enabled"
echo -e "  DNS: --accept-dns (CRITICAL for MagicDNS)"
echo

# Build tailscale up command
TAILSCALE_CMD="tailscale up"
TAILSCALE_CMD="$TAILSCALE_CMD --advertise-tags=$TAGS"
TAILSCALE_CMD="$TAILSCALE_CMD --accept-dns"  # CRITICAL: Required for MagicDNS
TAILSCALE_CMD="$TAILSCALE_CMD --accept-routes"
TAILSCALE_CMD="$TAILSCALE_CMD $SSH_ENABLED"
TAILSCALE_CMD="$TAILSCALE_CMD $ADVERTISE_ROUTES"
TAILSCALE_CMD="$TAILSCALE_CMD $EXIT_NODE"

echo -e "${CYAN}Running: $TAILSCALE_CMD${NC}"
echo

# Run the command (may require authentication)
if eval $TAILSCALE_CMD; then
    echo -e "${GREEN}✓ Tailscale configuration command executed${NC}"
else
    echo -e "${YELLOW}⚠ Command may require authentication${NC}"
    echo -e "${CYAN}If you see an auth URL, please authenticate in your browser${NC}"
fi

# Wait for connection to establish
echo -e "${CYAN}Waiting for connection to establish...${NC}"
sleep 5

echo

# ============================================================================
# Step 6: Verify and test
# ============================================================================
echo -e "${CYAN}[Step 6/6] Verifying configuration...${NC}"

# Check Tailscale status
if tailscale status &> /dev/null; then
    echo -e "${GREEN}✓ Tailscale is connected${NC}"
    
    # Check DNS
    STATUS_JSON=$(tailscale status --json 2>/dev/null || echo "{}")
    DNS_SERVER=$(echo "$STATUS_JSON" | jq -r '.Self.DNS // empty' 2>/dev/null || echo "")
    
    if [ -n "$DNS_SERVER" ] && [ "$DNS_SERVER" != "null" ]; then
        echo -e "${GREEN}✓ DNS configured: $DNS_SERVER${NC}"
    else
        echo -e "${YELLOW}⚠ DNS may take a few moments to configure${NC}"
    fi
    
    # Test DNS resolution
    echo -e "\n${CYAN}Testing DNS resolution...${NC}"
    
    # Test MagicDNS resolution
    if command -v dig &> /dev/null; then
        echo -e "${CYAN}Testing MagicDNS (.pangolin-vega.ts.net)...${NC}"
        if dig +short motoko.pangolin-vega.ts.net @100.100.100.100 &>/dev/null; then
            echo -e "${GREEN}✓ MagicDNS resolution working${NC}"
        else
            echo -e "${YELLOW}⚠ MagicDNS resolution may need more time${NC}"
        fi
    fi
    
    # Test regular DNS
    echo -e "${CYAN}Testing regular DNS (google.com)...${NC}"
    if ping -c 1 -W 2 google.com &>/dev/null; then
        echo -e "${GREEN}✓ Regular DNS resolution working${NC}"
    else
        echo -e "${RED}❌ Regular DNS resolution failed${NC}"
        echo -e "${YELLOW}Checking /etc/resolv.conf...${NC}"
        cat /etc/resolv.conf | sed 's/^/  /'
    fi
    
    echo
    echo -e "${CYAN}Final Tailscale status:${NC}"
    tailscale status | head -15 | sed 's/^/  /'
    
else
    echo -e "${RED}❌ Tailscale is not connected${NC}"
    echo -e "${YELLOW}Troubleshooting steps:${NC}"
    echo -e "  1. Check if tailscaled is running: systemctl status tailscaled"
    echo -e "  2. Check logs: journalctl -u tailscaled -n 50"
    echo -e "  3. Try manual connection: sudo tailscale up"
    exit 1
fi

echo
echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Fix Complete!                                           ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
echo
echo -e "${GREEN}Next steps:${NC}"
echo -e "  1. Test hostname resolution: ${CYAN}ping wintermute.pangolin-vega.ts.net${NC}"
echo -e "  2. Test SSH: ${CYAN}tailscale ssh mdt@wintermute.pangolin-vega.ts.net${NC}"
echo -e "  3. Verify DNS: ${CYAN}tailscale status --json | jq '.Self.DNS'${NC}"
echo -e "  4. Check service: ${CYAN}systemctl status tailscaled${NC}"
echo

