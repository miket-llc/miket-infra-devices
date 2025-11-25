#!/bin/bash
# Copyright (c) 2025 MikeT LLC. All rights reserved.

# Deploy vLLM to Armitage using proper Ansible architecture
# Uses: windows-vllm-deploy.yml playbook with windows-vllm-deploy role

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ANSIBLE_DIR="$REPO_ROOT/ansible"

cd "$ANSIBLE_DIR"

echo "================================================================"
echo "  Armitage vLLM Deployment (IaC/CaC)"
echo "================================================================"
echo ""
echo "Using: playbooks/windows-vllm-deploy.yml"
echo "Role:  windows-vllm-deploy"
echo ""

# Check connectivity
echo "Checking armitage connectivity..."
if ansible armitage -i inventory/hosts.yml -m win_ping >/dev/null 2>&1; then
    echo "✅ Armitage is reachable via WinRM"
    echo ""
    echo "Deploying vLLM configuration..."
    echo "================================================================"
    echo ""
    
    ansible-playbook \
        -i inventory/hosts.yml \
        playbooks/windows-vllm-deploy.yml \
        -e "target_hosts=armitage" \
        -v
    
    EXIT_CODE=$?
    
    echo ""
    echo "================================================================"
    if [ $EXIT_CODE -eq 0 ]; then
        echo "✅ Deployment completed successfully"
        echo "================================================================"
        exit 0
    else
        echo "❌ Deployment failed with exit code $EXIT_CODE"
        echo "================================================================"
        exit $EXIT_CODE
    fi
else
    echo "❌ Armitage is not reachable via WinRM"
    echo ""
    echo "Please ensure:"
    echo "  1. Armitage is powered on"
    echo "  2. Tailscale is running on armitage"
    echo "  3. WinRM is enabled and accessible"
    echo ""
    echo "To check WinRM on armitage:"
    echo "  Get-Service WinRM"
    echo "  Test-NetConnection -ComputerName localhost -Port 5985"
    echo ""
    exit 1
fi
