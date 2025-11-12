#!/bin/bash
# Monitor armitage connectivity and deploy Docker configuration when online
# This script will retry until armitage is reachable, then deploy

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ANSIBLE_DIR="$REPO_ROOT/ansible"
LOG_FILE="/tmp/armitage-docker-deploy-$(date +%Y%m%d_%H%M%S).log"

echo "================================================================"
echo "  Armitage Docker Configuration Deployment"
echo "================================================================"
echo ""
echo "Log file: $LOG_FILE"
echo ""

cd "$REPO_ROOT"

# Function to check connectivity
check_connectivity() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Checking armitage connectivity..."
    
    # Check ping
    if ping -c 1 -W 2 armitage.pangolin-vega.ts.net >/dev/null 2>&1; then
        echo "  ✓ Ping successful"
        
        # Check WinRM
        if cd "$ANSIBLE_DIR" && ansible armitage -i inventory/hosts.yml -m win_ping >/dev/null 2>&1; then
            echo "  ✓ WinRM accessible"
            return 0
        else
            echo "  ⚠ Ping works but WinRM not accessible"
            return 1
        fi
    else
        echo "  ✗ Armitage is offline (ping failed)"
        return 1
    fi
}

# Function to deploy
deploy_docker() {
    echo ""
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting Docker configuration deployment..."
    echo "================================================================"
    
    cd "$ANSIBLE_DIR"
    
    ansible-playbook \
        -i inventory/hosts.yml \
        playbooks/armitage-vllm-deploy-scripts.yml \
        --limit armitage \
        -v 2>&1 | tee -a "$LOG_FILE"
    
    DEPLOY_EXIT_CODE=$?
    
    if [ $DEPLOY_EXIT_CODE -eq 0 ]; then
        echo ""
        echo "================================================================"
        echo "✅ Deployment completed successfully!"
        echo "================================================================"
        return 0
    else
        echo ""
        echo "================================================================"
        echo "❌ Deployment failed with exit code $DEPLOY_EXIT_CODE"
        echo "================================================================"
        return 1
    fi
}

# Function to verify deployment
verify_deployment() {
    echo ""
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Verifying deployment..."
    
    cd "$ANSIBLE_DIR"
    
    # Check if scripts were deployed
    ansible armitage -i inventory/hosts.yml -m win_shell -a 'Test-Path "C:\Users\mdt\dev\armitage\scripts\Start-VLLM.ps1"' 2>&1 | grep -q "True" && echo "  ✓ Start-VLLM.ps1 deployed" || echo "  ✗ Start-VLLM.ps1 not found"
    
    # Check if config was deployed
    ansible armitage -i inventory/hosts.yml -m win_shell -a 'Test-Path "C:\Users\mdt\dev\armitage\config.yml"' 2>&1 | grep -q "True" && echo "  ✓ config.yml deployed" || echo "  ✗ config.yml not found"
    
    # Check Docker service
    ansible armitage -i inventory/hosts.yml -m win_shell -a 'Get-Service com.docker.service | Select-Object -ExpandProperty Status' 2>&1 | grep -q "Running" && echo "  ✓ Docker service is running" || echo "  ⚠ Docker service status unknown"
    
    # Check if vLLM container exists
    ansible armitage -i inventory/hosts.yml -m win_shell -a 'docker ps -a --filter name=vllm-armitage --format "{{.Names}}" 2>&1' 2>&1 | grep -q "vllm-armitage" && echo "  ✓ vLLM container found" || echo "  ⚠ vLLM container not found"
}

# Main deployment flow
MAX_RETRIES=${MAX_RETRIES:-30}
RETRY_INTERVAL=${RETRY_INTERVAL:-10}

echo "Waiting for armitage to come online..."
echo "Will retry up to $MAX_RETRIES times with ${RETRY_INTERVAL}s intervals"
echo ""

RETRY_COUNT=0
while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if check_connectivity; then
        echo ""
        echo "✅ Armitage is online! Proceeding with deployment..."
        echo ""
        
        if deploy_docker; then
            verify_deployment
            echo ""
            echo "Deployment complete! Check log file for details: $LOG_FILE"
            exit 0
        else
            echo ""
            echo "Deployment failed. Check log file for details: $LOG_FILE"
            echo "Attempting to troubleshoot..."
            troubleshoot
            exit 1
        fi
    fi
    
    RETRY_COUNT=$((RETRY_COUNT + 1))
    if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
        echo "  Retrying in ${RETRY_INTERVAL}s... (attempt $RETRY_COUNT/$MAX_RETRIES)"
        sleep $RETRY_INTERVAL
    fi
done

echo ""
echo "❌ Armitage did not come online after $MAX_RETRIES attempts"
echo "Please check:"
echo "  1. Is armitage powered on?"
echo "  2. Is Tailscale running on armitage?"
echo "  3. Is WinRM enabled and accessible?"
echo ""
echo "You can manually run the deployment when armitage is online:"
echo "  cd $ANSIBLE_DIR"
echo "  ansible-playbook -i inventory/hosts.yml playbooks/armitage-vllm-deploy-scripts.yml --limit armitage"
exit 1



