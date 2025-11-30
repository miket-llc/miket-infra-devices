#!/bin/bash
# Copyright (c) 2025 MikeT LLC. All rights reserved.

# ============================================================================
# Tailscale End-to-End Verification Script
# ============================================================================
# Tests point-to-point connectivity for SSH, NoMachine, WinRM, and MagicDNS
# across all nodes in the Tailscale network.
#
# Architecture:
#   - Policy (ACLs, SSH rules): miket-infra (Terraform)
#   - Device config: miket-infra-devices (Ansible)
#   - This script: Verifies E2E connectivity works correctly
#
# Requirements:
#   - Tailscale installed and authenticated
#   - nc (netcat) for port testing
#   - jq for JSON parsing
#
# Usage:
#   ./verify-tailscale-e2e.sh              # Test all devices
#   ./verify-tailscale-e2e.sh --device motoko   # Test specific device
#   ./verify-tailscale-e2e.sh --ssh-only        # SSH tests only
#   ./verify-tailscale-e2e.sh --quick           # Skip slow tests (SSH auth)
#
# Exit codes:
#   0 - All tests passed
#   1 - Some tests failed
#   2 - Prerequisites not met
# ============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ============================================================================
# Device configuration - aligned with ansible/inventory/hosts.yml
# Format: device="tags|ssh_user|expected_ports"
# ============================================================================
declare -A DEVICES=(
    ["motoko"]="tag:server,tag:linux,tag:ansible|mdt|22,4000"
    ["armitage"]="tag:workstation,tag:windows,tag:gaming|mdt|5985,4000"
    ["wintermute"]="tag:workstation,tag:windows,tag:gaming|mdt|5985,4000"
    ["count-zero"]="tag:workstation,tag:macos|miket|22,4000"
)

# Standard ports
SSH_PORT=22
NOMACHINE_PORT=4000
WINRM_PORT=5985

# Parse command-line arguments
SPECIFIC_DEVICE=""
SSH_ONLY=false
QUICK_MODE=false
VERBOSE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --device|-d)
            SPECIFIC_DEVICE="$2"
            shift 2
            ;;
        --ssh-only)
            SSH_ONLY=true
            shift
            ;;
        --quick|-q)
            QUICK_MODE=true
            shift
            ;;
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --help|-h)
            echo "Tailscale E2E Verification"
            echo ""
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --device, -d <name>  Test specific device only"
            echo "  --ssh-only           Run SSH tests only"
            echo "  --quick, -q          Skip slow tests (SSH auth verification)"
            echo "  --verbose, -v        Show detailed output"
            echo "  --help, -h           Show this help"
            echo ""
            echo "Devices: ${!DEVICES[*]}"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 2
            ;;
    esac
done

# ============================================================================
# Helper Functions
# ============================================================================

print_header() {
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

print_subheader() {
    echo -e "\n${CYAN}▸ $1${NC}"
}

print_result() {
    local test_name="$1"
    local result="$2"
    local detail="${3:-}"
    
    if [ "$result" == "PASS" ]; then
        echo -e "  ${GREEN}✓${NC} $test_name"
        [ -n "$detail" ] && [ "$VERBOSE" = true ] && echo -e "    ${CYAN}$detail${NC}"
    elif [ "$result" == "SKIP" ]; then
        echo -e "  ${YELLOW}⊘${NC} $test_name (skipped)"
    else
        echo -e "  ${RED}✗${NC} $test_name"
        [ -n "$detail" ] && echo -e "    ${YELLOW}→ $detail${NC}"
    fi
}

# ============================================================================
# Prerequisite Checks
# ============================================================================

check_prerequisites() {
    print_header "Prerequisite Checks"
    
    local prereq_failed=false
    
    # Check Tailscale installed
    if ! command -v tailscale &> /dev/null; then
        echo -e "${RED}✗ Tailscale not installed${NC}"
        prereq_failed=true
    else
        echo -e "${GREEN}✓ Tailscale installed${NC}"
    fi
    
    # Check Tailscale running
    if ! tailscale status &> /dev/null; then
        echo -e "${RED}✗ Tailscale not running or not authenticated${NC}"
        prereq_failed=true
    else
        echo -e "${GREEN}✓ Tailscale running${NC}"
    fi
    
    # Check jq installed
    if ! command -v jq &> /dev/null; then
        echo -e "${RED}✗ jq not installed (apt install jq)${NC}"
        prereq_failed=true
    else
        echo -e "${GREEN}✓ jq installed${NC}"
    fi
    
    # Check netcat installed
    if ! command -v nc &> /dev/null; then
        echo -e "${RED}✗ netcat not installed (apt install netcat)${NC}"
        prereq_failed=true
    else
        echo -e "${GREEN}✓ netcat installed${NC}"
    fi
    
    if [ "$prereq_failed" = true ]; then
        echo -e "\n${RED}Prerequisites not met. Exiting.${NC}"
        exit 2
    fi
    
    # Get current device info
    CURRENT_DEVICE=$(tailscale status --json | jq -r '.Self.DNSName' | cut -d'.' -f1)
    TAILNET_DOMAIN=$(tailscale status --json | jq -r '.MagicDNSSuffix')
    CURRENT_IP=$(tailscale ip -4)
    
    echo ""
    echo -e "Current device: ${YELLOW}${CURRENT_DEVICE}${NC} (${CURRENT_IP})"
    echo -e "Tailnet: ${YELLOW}${TAILNET_DOMAIN}${NC}"
}

# ============================================================================
# Test Functions
# ============================================================================

get_device_ip() {
    # Get device IP from tailscale status (more reliable than DNS)
    local device="$1"
    local status_json
    status_json=$(tailscale status --json 2>/dev/null)
    
    # Check if it's the current device (Self)
    local self_name
    self_name=$(echo "$status_json" | jq -r '.Self.HostName // .Self.DNSName' | cut -d'.' -f1)
    if [ "$device" == "$self_name" ]; then
        echo "$status_json" | jq -r '.Self.TailscaleIPs[0]' 2>/dev/null
        return
    fi
    
    # Check peers
    echo "$status_json" | jq -r ".Peer | to_entries[] | select(.value.HostName == \"$device\") | .value.TailscaleIPs[0]" 2>/dev/null
}

test_magicdns() {
    local device="$1"
    local fqdn="${device}.${TAILNET_DOMAIN}"
    
    if host "$fqdn" &> /dev/null; then
        local ip
        ip=$(host "$fqdn" | awk '/has address/ {print $NF; exit}')
        print_result "MagicDNS: $fqdn" "PASS" "→ $ip"
        return 0
    else
        # MagicDNS failed, but we can still test connectivity via Tailscale
        local ts_ip
        ts_ip=$(get_device_ip "$device")
        if [ -n "$ts_ip" ]; then
            print_result "MagicDNS: $fqdn" "FAIL" "DNS broken, using Tailscale IP: $ts_ip"
        else
            print_result "MagicDNS: $fqdn" "FAIL" "Cannot resolve and device not in tailscale status"
        fi
        return 1
    fi
}

test_ping() {
    local device="$1"
    local fqdn="${device}.${TAILNET_DOMAIN}"
    
    # Try hostname first, fall back to Tailscale IP
    if ping -c 1 -W 3 "$fqdn" &> /dev/null; then
        print_result "ICMP ping: $device" "PASS"
        return 0
    else
        # Try Tailscale IP directly
        local ts_ip
        ts_ip=$(get_device_ip "$device")
        if [ -n "$ts_ip" ] && ping -c 1 -W 3 "$ts_ip" &> /dev/null; then
            print_result "ICMP ping: $device ($ts_ip)" "PASS" "DNS failed, used Tailscale IP"
            return 0
        else
            print_result "ICMP ping: $device" "FAIL" "No response (device may be offline)"
            return 1
        fi
    fi
}

test_port() {
    local device="$1"
    local port="$2"
    local service="$3"
    local fqdn="${device}.${TAILNET_DOMAIN}"
    
    # Try hostname first, fall back to Tailscale IP
    if nc -zw3 "$fqdn" "$port" 2>/dev/null; then
        print_result "$service: $device:$port" "PASS"
        return 0
    else
        # Try Tailscale IP directly
        local ts_ip
        ts_ip=$(get_device_ip "$device")
        if [ -n "$ts_ip" ] && nc -zw3 "$ts_ip" "$port" 2>/dev/null; then
            print_result "$service: $device:$port ($ts_ip)" "PASS"
            return 0
        else
            print_result "$service: $device:$port" "FAIL" "Port not reachable"
            return 1
        fi
    fi
}

test_ssh_auth() {
    local device="$1"
    local ssh_user="$2"
    local fqdn="${device}.${TAILNET_DOMAIN}"
    
    # Skip if testing self
    if [ "$device" == "$CURRENT_DEVICE" ]; then
        print_result "SSH auth: $ssh_user@$device" "SKIP" "Cannot test self"
        return 0
    fi
    
    # Try hostname first
    if timeout 10 ssh -o ConnectTimeout=5 \
        -o StrictHostKeyChecking=accept-new \
        -o BatchMode=yes \
        "${ssh_user}@${fqdn}" \
        'echo ok' &> /dev/null; then
        print_result "SSH auth: $ssh_user@$device" "PASS"
        return 0
    fi
    
    # Try Tailscale IP if hostname failed
    local ts_ip
    ts_ip=$(get_device_ip "$device")
    if [ -n "$ts_ip" ] && timeout 10 ssh -o ConnectTimeout=5 \
        -o StrictHostKeyChecking=accept-new \
        -o BatchMode=yes \
        "${ssh_user}@${ts_ip}" \
        'echo ok' &> /dev/null; then
        print_result "SSH auth: $ssh_user@$device ($ts_ip)" "PASS"
        return 0
    fi
    
    print_result "SSH auth: $ssh_user@$device" "FAIL" "Authentication failed or timed out"
    return 1
}

# ============================================================================
# Main Test Loop
# ============================================================================

run_tests() {
    local total_tests=0
    local passed_tests=0
    local failed_tests=0
    local skipped_tests=0
    
    # Determine which devices to test
    local devices_to_test
    if [ -n "$SPECIFIC_DEVICE" ]; then
        if [ -z "${DEVICES[$SPECIFIC_DEVICE]:-}" ]; then
            echo -e "${RED}Unknown device: $SPECIFIC_DEVICE${NC}"
            echo "Available: ${!DEVICES[*]}"
            exit 2
        fi
        devices_to_test=("$SPECIFIC_DEVICE")
    else
        devices_to_test=("${!DEVICES[@]}")
    fi
    
    # Run tests for each device
    for device in "${devices_to_test[@]}"; do
        IFS='|' read -r tags ssh_user ports <<< "${DEVICES[$device]}"
        
        print_header "Testing: $device"
        echo -e "Tags: ${CYAN}$tags${NC}"
        echo -e "SSH User: ${CYAN}$ssh_user${NC}"
        echo -e "Expected Ports: ${CYAN}$ports${NC}"
        
        # MagicDNS test
        print_subheader "Network Connectivity"
        if test_magicdns "$device"; then
            ((passed_tests++)) || true
        else
            ((failed_tests++)) || true
        fi
        ((total_tests++)) || true
        
        # Ping test
        if test_ping "$device"; then
            ((passed_tests++)) || true
        else
            ((failed_tests++)) || true
        fi
        ((total_tests++)) || true
        
        # Port tests
        if [ "$SSH_ONLY" = false ]; then
            print_subheader "Service Ports"
            
            # Check expected ports based on device type
            if [[ "$tags" == *"tag:windows"* ]]; then
                # Windows: WinRM + NoMachine
                if test_port "$device" "$WINRM_PORT" "WinRM"; then
                    ((passed_tests++)) || true
                else
                    ((failed_tests++)) || true
                fi
                ((total_tests++)) || true
            else
                # Linux/macOS: SSH + NoMachine
                if test_port "$device" "$SSH_PORT" "SSH"; then
                    ((passed_tests++)) || true
                else
                    ((failed_tests++)) || true
                fi
                ((total_tests++)) || true
            fi
            
            # NoMachine (all devices)
            if test_port "$device" "$NOMACHINE_PORT" "NoMachine"; then
                ((passed_tests++)) || true
            else
                ((failed_tests++)) || true
            fi
            ((total_tests++)) || true
        fi
        
        # SSH authentication test (slow - skip in quick mode)
        if [ "$QUICK_MODE" = false ] && [[ "$tags" != *"tag:windows"* ]]; then
            print_subheader "SSH Authentication"
            if test_ssh_auth "$device" "$ssh_user"; then
                ((passed_tests++)) || true
            else
                ((failed_tests++)) || true
            fi
            ((total_tests++)) || true
        fi
    done
    
    # Print summary
    print_header "Test Summary"
    echo -e "Total tests:  ${YELLOW}$total_tests${NC}"
    echo -e "Passed:       ${GREEN}$passed_tests${NC}"
    echo -e "Failed:       ${RED}$failed_tests${NC}"
    
    if [ "$failed_tests" -eq 0 ]; then
        echo -e "\n${GREEN}✅ All tests passed!${NC}"
        return 0
    else
        echo -e "\n${RED}❌ $failed_tests test(s) failed${NC}"
        echo ""
        echo "Troubleshooting:"
        echo "  1. Check device is online: tailscale status"
        echo "  2. Verify ACL policy: cd miket-infra/infra/tailscale/entra-prod && terraform plan"
        echo "  3. Check firewall on target device"
        echo "  4. Verify Tailscale SSH enabled: tailscale up --ssh (on target)"
        return 1
    fi
}

# ============================================================================
# Entry Point
# ============================================================================

main() {
    echo -e "${BLUE}"
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║         Tailscale E2E Verification - miket-infra-devices       ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    check_prerequisites
    run_tests
}

main

