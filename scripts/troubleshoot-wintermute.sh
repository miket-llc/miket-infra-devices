#!/usr/bin/env bash
# Copyright (c) 2025 MikeT LLC. All rights reserved.

# troubleshoot-wintermute.sh
# Comprehensive connectivity troubleshooting script for wintermute
# Tests Tailscale, DNS, ports, and Ansible connectivity

set -uo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

HOSTNAME="wintermute"
FQDN="${HOSTNAME}.pangolin-vega.ts.net"
NOMACHINE_PORT=4000
WINRM_PORT=5985

PASSED=0
FAILED=0
WARNINGS=0

# Test results tracking
declare -A TEST_RESULTS

print_header() {
    echo ""
    echo -e "${BLUE}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║   $1${NC}"
    echo -e "${BLUE}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_test() {
    local test_name="$1"
    local status="$2"
    local message="${3:-}"
    
    if [ "$status" == "PASS" ]; then
        echo -e "  ${GREEN}✓${NC} $test_name"
        PASSED=$((PASSED + 1))
        TEST_RESULTS["$test_name"]="PASS"
    elif [ "$status" == "FAIL" ]; then
        echo -e "  ${RED}✗${NC} $test_name"
        if [ -n "$message" ]; then
            echo -e "      ${RED}→ $message${NC}"
        fi
        FAILED=$((FAILED + 1))
        TEST_RESULTS["$test_name"]="FAIL"
    elif [ "$status" == "WARN" ]; then
        echo -e "  ${YELLOW}⚠${NC} $test_name"
        if [ -n "$message" ]; then
            echo -e "      ${YELLOW}→ $message${NC}"
        fi
        WARNINGS=$((WARNINGS + 1))
        TEST_RESULTS["$test_name"]="WARN"
    fi
}

# Test 1: DNS Resolution
test_dns() {
    print_header "DNS Resolution Test"
    
    if host "$FQDN" &>/dev/null; then
        local ip=$(host "$FQDN" | grep -oP 'has address \K[0-9.]+' | head -1)
        print_test "DNS resolution for $FQDN" "PASS" "Resolves to $ip"
    else
        print_test "DNS resolution for $FQDN" "FAIL" "DNS lookup failed"
        return 1
    fi
}

# Test 2: Tailscale Status
test_tailscale_status() {
    print_header "Tailscale Status Check"
    
    if ! command -v tailscale &> /dev/null; then
        print_test "Tailscale command available" "WARN" "tailscale command not found (may be running from non-Tailscale host)"
        return 0
    fi
    
    local status_output=$(tailscale status 2>/dev/null | grep -i "$HOSTNAME" || true)
    
    if [ -z "$status_output" ]; then
        print_test "Wintermute in Tailscale status" "FAIL" "Wintermute not found in tailscale status"
        echo ""
        echo "  Run 'tailscale status' to see all devices"
        return 1
    else
        local ip=$(echo "$status_output" | awk '{print $1}')
        
        if echo "$status_output" | grep -q "offline"; then
            print_test "Wintermute Tailscale status" "FAIL" "Device is offline"
            echo "  Full status: $status_output"
        elif echo "$status_output" | grep -qE "(active|idle)"; then
            # Both "active" and "idle" indicate the device is online
            # "idle" means no recent traffic but device is reachable
            local status_type=$(echo "$status_output" | grep -oE "(active|idle)" | head -1)
            print_test "Wintermute Tailscale status" "PASS" "${status_type^} (IP: $ip)"
            echo "  Full status: $status_output"
        else
            print_test "Wintermute Tailscale status" "WARN" "Unknown status"
            echo "  Full status: $status_output"
        fi
    fi
}

# Test 3: Ping Connectivity
test_ping() {
    print_header "Ping Connectivity Test"
    
    if ping -c 3 -W 2 "$FQDN" &>/dev/null; then
        local ping_output=$(ping -c 3 "$FQDN" 2>&1 | tail -1)
        local avg_time=$(echo "$ping_output" | grep -oP 'avg = \K[0-9.]+' || echo "N/A")
        print_test "Ping to $FQDN" "PASS" "Average RTT: ${avg_time}ms"
    else
        print_test "Ping to $FQDN" "FAIL" "No response to ping"
        return 1
    fi
}

# Test 4: NoMachine Port (4000)
test_nomachine_port() {
    print_header "NoMachine Port Test (4000)"
    
    if command -v nc &> /dev/null; then
        if timeout 5 bash -c "echo > /dev/tcp/$FQDN/$NOMACHINE_PORT" 2>/dev/null; then
            print_test "NoMachine port $NOMACHINE_PORT" "PASS" "Port is open and accepting connections"
        else
            print_test "NoMachine port $NOMACHINE_PORT" "FAIL" "Port is not accessible"
            echo ""
            echo "  Troubleshooting steps:"
            echo "    1. Check if NoMachine service is running on wintermute"
            echo "    2. Verify Windows Firewall allows port 4000"
            echo "    3. Check Tailscale ACL rules allow access to port 4000"
        fi
    else
        print_test "NoMachine port test" "WARN" "nc (netcat) not available, skipping port test"
    fi
}

# Test 5: WinRM Port (5985)
test_winrm_port() {
    print_header "WinRM Port Test (5985)"
    
    if command -v nc &> /dev/null; then
        if timeout 5 bash -c "echo > /dev/tcp/$FQDN/$WINRM_PORT" 2>/dev/null; then
            print_test "WinRM port $WINRM_PORT" "PASS" "Port is open and accepting connections"
        else
            print_test "WinRM port $WINRM_PORT" "FAIL" "Port is not accessible"
            echo ""
            echo "  Troubleshooting steps:"
            echo "    1. Check if WinRM service is running on wintermute"
            echo "    2. Verify Windows Firewall allows port 5985"
            echo "    3. Check Tailscale ACL rules allow access to port 5985"
        fi
    else
        print_test "WinRM port test" "WARN" "nc (netcat) not available, skipping port test"
    fi
}

# Test 6: Ansible Connectivity
test_ansible_connectivity() {
    print_header "Ansible Connectivity Test"
    
    if ! command -v ansible &> /dev/null; then
        print_test "Ansible command available" "WARN" "ansible command not found"
        return 0
    fi
    
    local inventory_file="ansible/inventory/hosts.yml"
    if [ ! -f "$inventory_file" ]; then
        print_test "Ansible inventory file" "WARN" "Inventory file not found at $inventory_file"
        return 0
    fi
    
    echo "  Testing Ansible WinRM connection (requires vault password)..."
    local ansible_output=$(ansible "$HOSTNAME" -i "$inventory_file" -m win_ping 2>&1 || true)
    
    if echo "$ansible_output" | grep -q "SUCCESS"; then
        print_test "Ansible WinRM connection" "PASS" "Successfully connected via WinRM"
    elif echo "$ansible_output" | grep -q "UNREACHABLE"; then
        if echo "$ansible_output" | grep -q "requires a password"; then
            print_test "Ansible WinRM connection" "WARN" "Authentication failed - vault password required"
            echo ""
            echo "  To test with password, run:"
            echo "    ansible-playbook -i $inventory_file playbooks/smoke-windows-remote-access.yml --limit $HOSTNAME --ask-vault-pass"
        else
            print_test "Ansible WinRM connection" "FAIL" "Host unreachable"
            echo "  Output: $ansible_output"
        fi
    else
        print_test "Ansible WinRM connection" "WARN" "Unexpected response"
        echo "  Output: $ansible_output"
    fi
}

# Test 7: Tailscale Ping (if available)
test_tailscale_ping() {
    print_header "Tailscale Ping Test"
    
    if ! command -v tailscale &> /dev/null; then
        print_test "Tailscale ping" "WARN" "tailscale command not available"
        return 0
    fi
    
    local ping_output=$(tailscale ping "$HOSTNAME" 2>&1 || true)
    
    if echo "$ping_output" | grep -q "pong"; then
        local rtt=$(echo "$ping_output" | grep -oP 'pong from \K[0-9.]+' || echo "N/A")
        print_test "Tailscale ping to $HOSTNAME" "PASS" "RTT: ${rtt}ms"
    elif echo "$ping_output" | grep -q "is offline"; then
        print_test "Tailscale ping to $HOSTNAME" "FAIL" "Device is offline"
    else
        print_test "Tailscale ping to $HOSTNAME" "WARN" "Unexpected response: $ping_output"
    fi
}

# Summary
print_summary() {
    print_header "Test Summary"
    
    echo -e "  ${GREEN}Passed:${NC} $PASSED"
    echo -e "  ${RED}Failed:${NC} $FAILED"
    echo -e "  ${YELLOW}Warnings:${NC} $WARNINGS"
    echo ""
    
    if [ $FAILED -eq 0 ] && [ $WARNINGS -eq 0 ]; then
        echo -e "${GREEN}✓ All connectivity tests passed!${NC}"
        echo ""
        echo "Wintermute is fully accessible via:"
        echo "  - Tailscale: $FQDN"
        echo "  - NoMachine: $FQDN:$NOMACHINE_PORT"
        echo "  - WinRM: $FQDN:$WINRM_PORT"
        return 0
    elif [ $FAILED -eq 0 ]; then
        echo -e "${YELLOW}⚠ Some warnings detected, but no critical failures${NC}"
        echo ""
        echo "Wintermute connectivity is functional with minor issues."
        return 0
    else
        echo -e "${RED}✗ Some connectivity tests failed${NC}"
        echo ""
        echo "Next steps:"
        echo "  1. Check if wintermute is powered on and connected to network"
        echo "  2. Verify Tailscale client is running on wintermute"
        echo "  3. Check Windows Firewall rules on wintermute"
        echo "  4. Verify Tailscale ACL rules in miket-infra"
        echo ""
        echo "For detailed troubleshooting, see:"
        echo "  - docs/armitage-connectivity-troubleshooting.md (similar process)"
        echo "  - docs/runbooks/nomachine-client-testing.md"
        return 1
    fi
}

# Main execution
main() {
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║   Wintermute Connectivity Troubleshooting                    ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    # Change to script directory
    cd "$(dirname "$0")/.." || exit 1
    
    # Run tests
    test_dns
    test_tailscale_status
    test_ping
    test_tailscale_ping
    test_nomachine_port
    test_winrm_port
    test_ansible_connectivity
    
    # Print summary
    print_summary
    
    exit $?
}

main "$@"

