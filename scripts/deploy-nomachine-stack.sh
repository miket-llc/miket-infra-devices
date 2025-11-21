#!/usr/bin/env bash
# deploy-nomachine-stack.sh
# Complete NoMachine deployment script for MikeT LLC infrastructure
# Replaces VNC (Linux) and RDP (Windows) with unified NoMachine stack
#
# USAGE:
#   ./scripts/deploy-nomachine-stack.sh [--servers-only | --clients-only | --validate-only]
#
# FLAGS:
#   --servers-only    Deploy only NoMachine servers (skip clients)
#   --clients-only    Deploy only NoMachine clients (skip servers)
#   --validate-only   Run validation only (no deployment)
#   --skip-validation Skip validation after deployment
#   --help            Show this help message

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ANSIBLE_DIR="$REPO_ROOT/ansible"

# Deployment flags
DEPLOY_SERVERS=true
DEPLOY_CLIENTS=true
RUN_VALIDATION=true
VALIDATE_ONLY=false

# Parse command-line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --servers-only)
                DEPLOY_CLIENTS=false
                shift
                ;;
            --clients-only)
                DEPLOY_SERVERS=false
                shift
                ;;
            --validate-only)
                VALIDATE_ONLY=true
                DEPLOY_SERVERS=false
                DEPLOY_CLIENTS=false
                shift
                ;;
            --skip-validation)
                RUN_VALIDATION=false
                shift
                ;;
            --help)
                grep "^#" "$0" | grep -v "^#!/" | sed 's/^# //'
                exit 0
                ;;
            *)
                echo -e "${RED}Unknown option: $1${NC}"
                echo "Run with --help for usage information"
                exit 1
                ;;
        esac
    done
}

# Display banner
banner() {
    echo -e "${BLUE}"
    cat << 'EOF'
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║   NoMachine Unified Remote Desktop Stack Deployment          ║
║   MikeT LLC Infrastructure                                    ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

# Check prerequisites
check_prerequisites() {
    echo -e "${BLUE}[1/8] Checking prerequisites...${NC}"
    
    if ! command -v ansible-playbook &> /dev/null; then
        echo -e "${RED}ERROR: ansible-playbook not found${NC}"
        echo "Install Ansible: pip3 install ansible"
        exit 1
    fi
    
    if [ ! -d "$ANSIBLE_DIR" ]; then
        echo -e "${RED}ERROR: Ansible directory not found: $ANSIBLE_DIR${NC}"
        exit 1
    fi
    
    if [ ! -f "$ANSIBLE_DIR/inventory/hosts.yml" ]; then
        echo -e "${RED}ERROR: Ansible inventory not found${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✓ Prerequisites OK${NC}"
    echo ""
}

# Display deployment plan
display_plan() {
    echo -e "${BLUE}[2/8] Deployment Plan${NC}"
    echo ""
    
    if $VALIDATE_ONLY; then
        echo "Mode: VALIDATION ONLY"
        echo ""
        echo "Actions:"
        echo "  • Run NoMachine deployment validation"
        echo ""
        return
    fi
    
    echo "Target Architecture:"
    echo "  • Linux (motoko):      NoMachine server (VNC removed)"
    echo "  • Windows (wintermute, armitage): NoMachine server (RDP disabled)"
    echo "  • macOS (count-zero):  NoMachine client"
    echo "  • All platforms:       NoMachine client installed"
    echo ""
    
    if $DEPLOY_SERVERS; then
        echo -e "${YELLOW}Server Deployment (Phase 1):${NC}"
        echo "  ✓ Install NoMachine on Linux (motoko)"
        echo "  ✓ Stop and remove VNC services and packages"
        echo "  ✓ Install NoMachine on Windows (wintermute, armitage)"
        echo "  ✓ Disable RDP service and block port 3389"
        echo "  ✓ Configure firewalls (Tailscale 100.64.0.0/10 only)"
        echo ""
    fi
    
    if $DEPLOY_CLIENTS; then
        echo -e "${YELLOW}Client Deployment (Phase 2):${NC}"
        echo "  ✓ Install NoMachine client on all platforms"
        echo "  ✓ Pre-configure server connections"
        echo ""
    fi
    
    if $RUN_VALIDATION; then
        echo -e "${YELLOW}Validation (Phase 3):${NC}"
        echo "  ✓ Verify NoMachine servers running"
        echo "  ✓ Verify VNC removed"
        echo "  ✓ Verify RDP disabled"
        echo "  ✓ Verify firewall rules"
        echo ""
    fi
    
    echo -e "${BLUE}Filesystem Invariants:${NC}"
    echo "  • /space, /flux, /time remain unchanged"
    echo "  • NoMachine configs in OS-standard locations only"
    echo "  • SMB shares (S:\\, X:\\, T:\\) unaffected"
    echo ""
}

# Confirm deployment
confirm_deployment() {
    if $VALIDATE_ONLY; then
        read -p "Run validation now? (y/N): " -n 1 -r
    else
        echo -e "${YELLOW}⚠️  This will modify remote desktop configuration across all devices${NC}"
        read -p "Continue with deployment? (y/N): " -n 1 -r
    fi
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${RED}Deployment cancelled${NC}"
        exit 1
    fi
    echo ""
}

# Deploy NoMachine servers
deploy_servers() {
    echo -e "${BLUE}[3/8] Deploying NoMachine Servers...${NC}"
    echo ""
    
    cd "$ANSIBLE_DIR"
    
    if ansible-playbook -i inventory/hosts.yml playbooks/remote_server.yml --ask-vault-pass; then
        echo ""
        echo -e "${GREEN}✓ NoMachine servers deployed successfully${NC}"
        echo ""
    else
        echo ""
        echo -e "${RED}✗ Server deployment failed${NC}"
        echo "Check Ansible output above for errors"
        exit 1
    fi
}

# Deploy NoMachine clients
deploy_clients() {
    echo -e "${BLUE}[4/8] Deploying NoMachine Clients...${NC}"
    echo ""
    
    cd "$ANSIBLE_DIR"
    
    if ansible-playbook -i inventory/hosts.yml playbooks/remote_clients_nomachine.yml --ask-vault-pass; then
        echo ""
        echo -e "${GREEN}✓ NoMachine clients deployed successfully${NC}"
        echo ""
    else
        echo ""
        echo -e "${RED}✗ Client deployment failed${NC}"
        echo "Check Ansible output above for errors"
        exit 1
    fi
}

# Run validation
validate_deployment() {
    echo -e "${BLUE}[5/8] Validating NoMachine Deployment...${NC}"
    echo ""
    
    cd "$ANSIBLE_DIR"
    
    if ansible-playbook -i inventory/hosts.yml playbooks/validate_nomachine_deployment.yml --ask-vault-pass; then
        echo ""
        echo -e "${GREEN}✓ Validation passed${NC}"
        echo ""
    else
        echo ""
        echo -e "${YELLOW}⚠️  Validation reported issues${NC}"
        echo "Review output above"
        echo ""
    fi
}

# Display connection information
display_connection_info() {
    echo -e "${BLUE}[6/8] Connection Information${NC}"
    echo ""
    echo "NoMachine Servers:"
    echo "  • motoko:     motoko.pangolin-vega.ts.net:4000"
    echo "  • wintermute: wintermute.pangolin-vega.ts.net:4000"
    echo "  • armitage:   armitage.pangolin-vega.ts.net:4000"
    echo ""
    echo "Launch NoMachine Client:"
    echo "  • macOS:   /Applications/NoMachine.app"
    echo "  • Windows: Start Menu > NoMachine"
    echo "  • Linux:   Applications > NoMachine or run 'nxplayer'"
    echo ""
    echo "Security:"
    echo "  • All connections restricted to Tailscale (100.64.0.0/10)"
    echo "  • Port 4000/TCP for NoMachine"
    echo "  • VNC ports (5900+) no longer listening"
    echo "  • Windows RDP (3389) disabled and firewalled"
    echo ""
}

# Display testing checklist
display_testing_checklist() {
    echo -e "${BLUE}[7/8] Manual Testing Checklist${NC}"
    echo ""
    echo "Test from each client platform:"
    echo ""
    echo "  [ ] From count-zero (macOS) to motoko:"
    echo "      - Launch NoMachine"
    echo "      - Connect to motoko.pangolin-vega.ts.net:4000"
    echo "      - Verify GNOME desktop appears"
    echo "      - Test clipboard (copy/paste both directions)"
    echo "      - Test multi-monitor if available"
    echo "      - Open Files and verify ~/space, ~/flux visible"
    echo ""
    echo "  [ ] From count-zero (macOS) to wintermute:"
    echo "      - Connect to wintermute.pangolin-vega.ts.net:4000"
    echo "      - Verify Windows desktop appears"
    echo "      - Test clipboard"
    echo "      - Verify S:\\ and X:\\ drives accessible"
    echo ""
    echo "  [ ] From Windows (wintermute or armitage) to motoko:"
    echo "      - Launch NoMachine client"
    echo "      - Connect to motoko"
    echo "      - Verify full desktop functionality"
    echo ""
    echo "  [ ] Verify RDP is disabled:"
    echo "      - Try to connect via RDP to wintermute:3389 (should fail)"
    echo "      - Try to connect via RDP to armitage:3389 (should fail)"
    echo ""
    echo "  [ ] Network resilience:"
    echo "      - Disconnect/reconnect Tailscale"
    echo "      - Verify NoMachine auto-reconnects"
    echo ""
    echo "  [ ] Filesystem access:"
    echo "      - From remote session, edit a file in ~/space"
    echo "      - Verify changes appear on motoko's physical filesystem"
    echo "      - Confirm no NoMachine data written to /space, /flux, /time"
    echo ""
}

# Display rollback instructions
display_rollback_info() {
    echo -e "${BLUE}[8/8] Rollback Information${NC}"
    echo ""
    echo "If you need to rollback to RDP on Windows:"
    echo ""
    echo "  Option 1: Use Makefile"
    echo "    cd $REPO_ROOT"
    echo "    make rollback-nomachine"
    echo ""
    echo "  Option 2: Use Ansible directly"
    echo "    cd $ANSIBLE_DIR"
    echo "    ansible-playbook -i inventory/hosts.yml playbooks/rollback_nomachine.yml --ask-vault-pass"
    echo ""
    echo "Note: VNC will NOT be restored on Linux. NoMachine remains the"
    echo "      standard for Linux remote desktop."
    echo ""
}

# Display final summary
display_summary() {
    echo -e "${GREEN}"
    cat << 'EOF'
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║   ✓ NoMachine Deployment Complete                            ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    
    echo "Next Steps:"
    echo "  1. Complete the manual testing checklist above"
    echo "  2. Test from each client device"
    echo "  3. Verify S:\\, X:\\, ~/space, ~/flux work in remote sessions"
    echo "  4. Update team documentation with new connection info"
    echo ""
    echo "Questions or issues?"
    echo "  • Check logs in /var/log/nx on Linux"
    echo "  • Check C:\\Program Files\\NoMachine\\var\\log on Windows"
    echo "  • Re-run validation: make validate-nomachine"
    echo ""
}

# Main execution
main() {
    parse_args "$@"
    
    banner
    check_prerequisites
    display_plan
    confirm_deployment
    
    if $VALIDATE_ONLY; then
        validate_deployment
        exit 0
    fi
    
    if $DEPLOY_SERVERS; then
        deploy_servers
    else
        echo -e "${YELLOW}[3/8] Skipping server deployment${NC}"
        echo ""
    fi
    
    if $DEPLOY_CLIENTS; then
        deploy_clients
    else
        echo -e "${YELLOW}[4/8] Skipping client deployment${NC}"
        echo ""
    fi
    
    if $RUN_VALIDATION; then
        validate_deployment
    else
        echo -e "${YELLOW}[5/8] Skipping validation${NC}"
        echo ""
    fi
    
    display_connection_info
    display_testing_checklist
    display_rollback_info
    display_summary
}

main "$@"


