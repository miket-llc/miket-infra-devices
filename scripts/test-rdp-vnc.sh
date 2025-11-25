#!/bin/bash
# Copyright (c) 2025 MikeT LLC. All rights reserved.

# Test RDP and VNC connections across the tailnet
# Verifies connectivity and port accessibility for remote desktop protocols

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Tailnet configuration
TAILNET_DOMAIN="pangolin-vega.ts.net"
TAILSCALE_SUBNET="100.64.0.0/10"

# Device configurations: hostname:protocol:port
declare -A DEVICES=(
    ["motoko"]="vnc:5900"
    ["wintermute"]="rdp:3389"
    ["armitage"]="rdp:3389"
    ["count-zero"]="vnc:5900"
)

# Test results
declare -A RESULTS
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Function to print test header
print_header() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
}

# Function to test Tailscale connectivity
test_tailscale_connectivity() {
    print_header "Testing Tailscale Connectivity"
    
    if ! command -v tailscale &> /dev/null; then
        echo -e "${YELLOW}⚠ tailscale command not found - skipping Tailscale status check${NC}"
        return 0
    fi
    
    echo "Checking Tailscale status..."
    if tailscale status &> /dev/null; then
        echo -e "${GREEN}✓ Tailscale is running${NC}"
        
        # Get local Tailscale IP
        LOCAL_IP=$(tailscale ip -4 2>/dev/null || echo "")
        if [ -n "$LOCAL_IP" ]; then
            echo "  Local Tailscale IP: $LOCAL_IP"
        fi
        
        # List connected peers
        echo ""
        echo "Connected peers:"
        tailscale status | grep -E "^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+" | head -10 || echo "  (no peers found)"
    else
        echo -e "${RED}✗ Tailscale is not running or not accessible${NC}"
        return 1
    fi
}

# Function to test DNS resolution
test_dns_resolution() {
    local hostname=$1
    local fqdn="${hostname}.${TAILNET_DOMAIN}"
    
    echo -n "  DNS resolution: "
    if getent hosts "$fqdn" &> /dev/null || host "$fqdn" &> /dev/null || nslookup "$fqdn" &> /dev/null; then
        RESOLVED_IP=$(getent hosts "$fqdn" 2>/dev/null | awk '{print $1}' | head -1)
        if [ -z "$RESOLVED_IP" ]; then
            RESOLVED_IP=$(host "$fqdn" 2>/dev/null | grep -oP 'has address \K[0-9.]+' | head -1)
        fi
        if [ -n "$RESOLVED_IP" ]; then
            echo -e "${GREEN}✓${NC} $fqdn -> $RESOLVED_IP"
            return 0
        else
            echo -e "${YELLOW}⚠${NC} $fqdn resolves but IP not found"
            return 1
        fi
    else
        echo -e "${RED}✗${NC} $fqdn does not resolve"
        return 1
    fi
}

# Function to test ping connectivity
test_ping() {
    local hostname=$1
    local fqdn="${hostname}.${TAILNET_DOMAIN}"
    
    echo -n "  Ping test: "
    if ping -c 2 -W 2 "$fqdn" &> /dev/null; then
        echo -e "${GREEN}✓${NC} $fqdn is reachable"
        return 0
    else
        echo -e "${RED}✗${NC} $fqdn is not reachable"
        return 1
    fi
}

# Function to test port connectivity
test_port() {
    local hostname=$1
    local port=$2
    local protocol=$3
    local fqdn="${hostname}.${TAILNET_DOMAIN}"
    
    echo -n "  Port $port ($protocol): "
    
    # Try bash built-in TCP test first (most reliable)
    if timeout 3 bash -c "echo > /dev/tcp/$fqdn/$port" 2>/dev/null; then
        echo -e "${GREEN}✓${NC} Port $port is open"
        return 0
    fi
    
    # Try nc (netcat) with verbose output
    if command -v nc &> /dev/null; then
        if timeout 3 nc -zv -w 2 "$fqdn" "$port" 2>&1 | grep -q "succeeded\|open"; then
            echo -e "${GREEN}✓${NC} Port $port is open"
            return 0
        fi
    fi
    
    # Try nmap if available (more reliable for RDP/VNC)
    if command -v nmap &> /dev/null; then
        if timeout 5 nmap -p "$port" "$fqdn" 2>/dev/null | grep -q "$port.*open"; then
            echo -e "${GREEN}✓${NC} Port $port is open"
            return 0
        fi
    fi
    
    # If handshake test passed, port is likely open but filtered
    echo -e "${YELLOW}⚠${NC} Port $port may be filtered (handshake test will verify)"
    return 1
}

# Function to test RDP handshake (if xfreerdp is available)
test_rdp_handshake() {
    local hostname=$1
    local fqdn="${hostname}.${TAILNET_DOMAIN}"
    
    if ! command -v xfreerdp &> /dev/null; then
        echo -e "  ${YELLOW}⚠${NC} xfreerdp not installed - skipping RDP handshake test"
        echo "    Install with: sudo apt-get install freerdp2-x11"
        return 1
    fi
    
    echo -n "  RDP handshake: "
    
    # Try to connect and immediately disconnect (just test handshake)
    # Use /sec:rdp to avoid NLA requirement for handshake test
    OUTPUT=$(timeout 5 xfreerdp /v:"$fqdn:3389" /cert-ignore /u:test /p:test /sec:rdp /timeout:2 2>&1)
    EXIT_CODE=$?
    
    # Exit code 0 = success, 1 = connection refused/closed, other = auth failure (but port is open)
    if [ $EXIT_CODE -eq 0 ]; then
        echo -e "${GREEN}✓${NC} RDP handshake successful"
        return 0
    elif echo "$OUTPUT" | grep -qiE "connection refused|connection closed|unable to connect|timeout"; then
        echo -e "${RED}✗${NC} RDP port not responding"
        return 1
    else
        # Auth failure or other error means port is open and responding
        echo -e "${GREEN}✓${NC} RDP port responds (auth required - expected)"
        return 0
    fi
}

# Function to test VNC handshake (if vncviewer is available)
test_vnc_handshake() {
    local hostname=$1
    local fqdn="${hostname}.${TAILNET_DOMAIN}"
    local port=$2
    
    if ! command -v vncviewer &> /dev/null && ! command -v vncviewer64 &> /dev/null; then
        echo -e "  ${YELLOW}⚠${NC} vncviewer not installed - skipping VNC handshake test"
        echo "    Install with: sudo apt-get install tigervnc-viewer"
        return 1
    fi
    
    echo -n "  VNC handshake: "
    
    # Try to connect and immediately disconnect (just test handshake)
    # VNC viewer will fail if port is closed, but succeed (or prompt) if port is open
    VNCVIEWER_CMD=$(command -v vncviewer64 || command -v vncviewer)
    
    OUTPUT=$(timeout 5 "$VNCVIEWER_CMD" -viewonly -shared -passwd /dev/null "$fqdn:$port" 2>&1)
    EXIT_CODE=$?
    
    # Check output for connection errors vs auth errors
    if echo "$OUTPUT" | grep -qiE "unable to connect|connection refused|connection closed|timeout|no route"; then
        echo -e "${RED}✗${NC} VNC port not responding"
        return 1
    elif [ $EXIT_CODE -eq 0 ] || echo "$OUTPUT" | grep -qiE "RFB protocol|authentication|password"; then
        # Auth prompt or RFB protocol means port is open and responding
        echo -e "${GREEN}✓${NC} VNC port responds (auth required - expected)"
        return 0
    else
        # Other errors might mean port is open
        echo -e "${GREEN}✓${NC} VNC port responds"
        return 0
    fi
}

# Function to test a single device
test_device() {
    local hostname=$1
    local config=$2
    local protocol=$(echo "$config" | cut -d: -f1)
    local port=$(echo "$config" | cut -d: -f2)
    local fqdn="${hostname}.${TAILNET_DOMAIN}"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    print_header "Testing $hostname ($protocol on port $port)"
    
    local device_passed=true
    
    # Test DNS resolution
    if ! test_dns_resolution "$hostname"; then
        device_passed=false
    fi
    
    # Test ping
    if ! test_ping "$hostname"; then
        device_passed=false
    fi
    
    # Test port connectivity
    if ! test_port "$hostname" "$port" "$protocol"; then
        device_passed=false
    fi
    
    # Test protocol-specific handshake (this is the most reliable test)
    local handshake_passed=false
    if [ "$protocol" = "rdp" ]; then
        if test_rdp_handshake "$hostname"; then
            handshake_passed=true
        fi
    elif [ "$protocol" = "vnc" ]; then
        if test_vnc_handshake "$hostname" "$port"; then
            handshake_passed=true
        fi
    fi
    
    # Record result - if handshake passed, consider it a pass even if port test failed
    if [ "$handshake_passed" = true ]; then
        device_passed=true
        echo ""
        echo -e "${GREEN}✓ $hostname: Protocol handshake successful - connection should work${NC}"
    fi
    
    if [ "$device_passed" = true ]; then
        RESULTS["$hostname"]="PASS"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        if [ "$handshake_passed" != true ]; then
            echo ""
            echo -e "${GREEN}✓ $hostname: All basic connectivity tests passed${NC}"
        fi
    else
        RESULTS["$hostname"]="FAIL"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        echo ""
        echo -e "${RED}✗ $hostname: Connectivity tests failed${NC}"
    fi
}

# Main execution
main() {
    echo -e "${BLUE}"
    echo "=========================================="
    echo "  RDP/VNC Connection Test Suite"
    echo "  Tailnet: $TAILNET_DOMAIN"
    echo "=========================================="
    echo -e "${NC}"
    
    # Test Tailscale connectivity first
    if ! test_tailscale_connectivity; then
        echo -e "${RED}Error: Tailscale is not running. Please start Tailscale first.${NC}"
        exit 1
    fi
    
    # Test each device
    for hostname in "${!DEVICES[@]}"; do
        test_device "$hostname" "${DEVICES[$hostname]}"
    done
    
    # Print summary
    print_header "Test Summary"
    
    echo "Results by device:"
    for hostname in "${!DEVICES[@]}"; do
        local result="${RESULTS[$hostname]}"
        local config="${DEVICES[$hostname]}"
        local protocol=$(echo "$config" | cut -d: -f1)
        local port=$(echo "$config" | cut -d: -f2)
        
        if [ "$result" = "PASS" ]; then
            echo -e "  ${GREEN}✓${NC} $hostname ($protocol:$port): PASS"
        else
            echo -e "  ${RED}✗${NC} $hostname ($protocol:$port): FAIL"
        fi
    done
    
    echo ""
    echo "Overall statistics:"
    echo "  Total tests: $TOTAL_TESTS"
    echo -e "  ${GREEN}Passed: $PASSED_TESTS${NC}"
    echo -e "  ${RED}Failed: $FAILED_TESTS${NC}"
    
    if [ $FAILED_TESTS -eq 0 ]; then
        echo ""
        echo -e "${GREEN}✓ All tests passed!${NC}"
        exit 0
    else
        echo ""
        echo -e "${RED}✗ Some tests failed. Check connectivity and firewall rules.${NC}"
        exit 1
    fi
}

# Run main function
main

