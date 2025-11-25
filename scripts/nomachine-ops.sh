#!/usr/bin/env bash
# Copyright (c) 2025 MikeT LLC. All rights reserved.

# nomachine-ops.sh
# Quick operations script for NoMachine stack
# Common administrative tasks for daily operations

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

show_help() {
    cat << 'EOF'
NoMachine Operations Quick Reference

USAGE: ./scripts/nomachine-ops.sh <command>

COMMANDS:
  status              Show status of all NoMachine servers
  restart-server      Restart NoMachine server on current host
  check-ports         Verify NoMachine ports are listening
  check-vnc           Verify VNC is NOT running (Linux)
  check-rdp           Verify RDP is disabled (Windows)
  test-connectivity   Test NoMachine connectivity from this host
  logs                Show NoMachine logs (current host)
  firewall-status     Show firewall rules for remote desktop

EXAMPLES:
  # Check status of all servers
  ./scripts/nomachine-ops.sh status

  # Restart NoMachine on current host
  ./scripts/nomachine-ops.sh restart-server

  # View logs
  ./scripts/nomachine-ops.sh logs
EOF
}

# Detect OS
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "linux"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
        echo "windows"
    else
        echo "unknown"
    fi
}

# Show status of all NoMachine servers
show_status() {
    echo -e "${BLUE}NoMachine Server Status${NC}"
    echo ""
    
    echo "Checking motoko (Linux)..."
    if ssh motoko.pangolin-vega.ts.net "systemctl is-active nxserver" &>/dev/null; then
        echo -e "  motoko:     ${GREEN}RUNNING${NC}"
    else
        echo -e "  motoko:     ${RED}STOPPED${NC}"
    fi
    
    echo "Checking wintermute (Windows)..."
    if nc -z -w2 wintermute.pangolin-vega.ts.net 4000 &>/dev/null; then
        echo -e "  wintermute: ${GREEN}LISTENING on port 4000${NC}"
    else
        echo -e "  wintermute: ${RED}NOT RESPONDING${NC}"
    fi
    
    echo "Checking armitage (Windows)..."
    if nc -z -w2 armitage.pangolin-vega.ts.net 4000 &>/dev/null; then
        echo -e "  armitage:   ${GREEN}LISTENING on port 4000${NC}"
    else
        echo -e "  armitage:   ${RED}NOT RESPONDING${NC}"
    fi
    
    echo ""
}

# Restart NoMachine server on current host
restart_server() {
    local os=$(detect_os)
    
    echo -e "${BLUE}Restarting NoMachine server...${NC}"
    
    if [[ "$os" == "linux" ]]; then
        sudo systemctl restart nxserver
        echo -e "${GREEN}✓ NoMachine restarted (Linux)${NC}"
    elif [[ "$os" == "windows" ]]; then
        net stop nxserver
        net start nxserver
        echo -e "${GREEN}✓ NoMachine restarted (Windows)${NC}"
    elif [[ "$os" == "macos" ]]; then
        sudo /usr/NX/bin/nxserver --restart
        echo -e "${GREEN}✓ NoMachine restarted (macOS)${NC}"
    else
        echo -e "${RED}✗ OS not detected${NC}"
        exit 1
    fi
}

# Check if NoMachine ports are listening
check_ports() {
    local os=$(detect_os)
    
    echo -e "${BLUE}Checking NoMachine ports...${NC}"
    echo ""
    
    if [[ "$os" == "linux" ]]; then
        if ss -tulnp | grep -q ":4000"; then
            echo -e "${GREEN}✓ Port 4000 is listening${NC}"
            ss -tulnp | grep ":4000"
        else
            echo -e "${RED}✗ Port 4000 is NOT listening${NC}"
        fi
    elif [[ "$os" == "macos" ]]; then
        if lsof -nP -iTCP:4000 | grep -q LISTEN; then
            echo -e "${GREEN}✓ Port 4000 is listening${NC}"
            lsof -nP -iTCP:4000 | grep LISTEN
        else
            echo -e "${RED}✗ Port 4000 is NOT listening${NC}"
        fi
    else
        echo "Run 'netstat -an | findstr :4000' on Windows"
    fi
    
    echo ""
}

# Verify VNC is not running (Linux only)
check_vnc() {
    local os=$(detect_os)
    
    if [[ "$os" != "linux" ]]; then
        echo "VNC check is only applicable to Linux hosts"
        return
    fi
    
    echo -e "${BLUE}Checking VNC status (should be removed)...${NC}"
    echo ""
    
    if ss -tulnp | grep -E ":(5900|5901|5902|5903)"; then
        echo -e "${RED}✗ WARNING: VNC ports are still listening!${NC}"
    else
        echo -e "${GREEN}✓ No VNC ports listening (as expected)${NC}"
    fi
    
    if systemctl is-active tigervnc.service &>/dev/null; then
        echo -e "${RED}✗ WARNING: TigerVNC service is still active!${NC}"
    else
        echo -e "${GREEN}✓ TigerVNC service is inactive (as expected)${NC}"
    fi
    
    echo ""
}

# Verify RDP is disabled (Windows only)
check_rdp() {
    echo "For Windows hosts, run this PowerShell command:"
    echo ""
    echo "  Get-Service TermService | Select-Object Status"
    echo "  Get-NetTCPConnection -LocalPort 3389 -ErrorAction SilentlyContinue"
    echo "  Get-NetFirewallRule -Name 'Block-RDP-All' | Select-Object Enabled,Action"
    echo ""
    echo "Expected:"
    echo "  TermService:  Stopped"
    echo "  Port 3389:    No output (not listening)"
    echo "  Firewall:     Enabled, Block"
    echo ""
}

# Test connectivity to NoMachine servers
test_connectivity() {
    echo -e "${BLUE}Testing NoMachine connectivity...${NC}"
    echo ""
    
    for host in motoko wintermute armitage; do
        echo -n "Testing $host.pangolin-vega.ts.net:4000... "
        if nc -z -w3 "$host.pangolin-vega.ts.net" 4000 &>/dev/null; then
            echo -e "${GREEN}OK${NC}"
        else
            echo -e "${RED}FAILED${NC}"
        fi
    done
    
    echo ""
}

# Show NoMachine logs
show_logs() {
    local os=$(detect_os)
    
    echo -e "${BLUE}NoMachine Logs${NC}"
    echo ""
    
    if [[ "$os" == "linux" ]]; then
        echo "Server logs:"
        sudo tail -50 /usr/NX/var/log/nxserver.log
    elif [[ "$os" == "macos" ]]; then
        echo "Server logs:"
        sudo tail -50 /Library/Logs/NoMachine/nxserver.log 2>/dev/null || \
            echo "Logs not found at standard location"
    else
        echo "On Windows, check: C:\\Program Files\\NoMachine\\var\\log\\nxserver.log"
    fi
    
    echo ""
}

# Show firewall status
show_firewall() {
    local os=$(detect_os)
    
    echo -e "${BLUE}Firewall Status for Remote Desktop${NC}"
    echo ""
    
    if [[ "$os" == "linux" ]]; then
        echo "UFW rules:"
        sudo ufw status verbose | grep -E "(4000|5900|3389)" || echo "No relevant rules found"
    elif [[ "$os" == "macos" ]]; then
        echo "macOS firewall (pfctl) - check manually"
        echo "System Preferences > Security & Privacy > Firewall"
    else
        echo "On Windows, run:"
        echo "  Get-NetFirewallRule | Where-Object { \$_.LocalPort -eq 4000 -or \$_.Name -like '*NoMachine*' }"
    fi
    
    echo ""
}

# Main
main() {
    if [[ $# -eq 0 ]]; then
        show_help
        exit 0
    fi
    
    case "$1" in
        status)
            show_status
            ;;
        restart-server)
            restart_server
            ;;
        check-ports)
            check_ports
            ;;
        check-vnc)
            check_vnc
            ;;
        check-rdp)
            check_rdp
            ;;
        test-connectivity)
            test_connectivity
            ;;
        logs)
            show_logs
            ;;
        firewall-status)
            show_firewall
            ;;
        --help|-h|help)
            show_help
            ;;
        *)
            echo -e "${RED}Unknown command: $1${NC}"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

main "$@"


