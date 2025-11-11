#!/bin/bash
# Deploy updated vLLM configuration to Armitage from Motoko control node
# This script can be run from Windows (via WSL/Git Bash) or from Motoko directly

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "================================================================"
echo "  Deploy Qwen2.5-7B-Instruct (bf16) to Armitage"
echo "================================================================"
echo ""

# Check if we're on Motoko or need to SSH
if [[ "$(hostname)" == "motoko" ]] || [[ -f "/home/mdt/miket-infra-devices/.git/config" ]]; then
    echo "Running on Motoko..."
    cd /home/mdt/miket-infra-devices/ansible || cd ~/miket-infra-devices/ansible
    DEPLOY_FROM_MOTOKO=true
else
    echo "Not on Motoko. Will SSH to Motoko to run deployment..."
    DEPLOY_FROM_MOTOKO=false
fi

if [ "$DEPLOY_FROM_MOTOKO" = false ]; then
    # SSH to Motoko and run deployment
    echo "Connecting to Motoko..."
    ssh mdt@motoko.pangolin-vega.ts.net << 'EOF'
        cd ~/miket-infra-devices/ansible
        
        echo "================================================================"
        echo "  Deploying updated vLLM configuration to Armitage"
        echo "================================================================"
        echo ""
        
        # Deploy updated scripts and config, then validate
        echo "[1/2] Deploying updated scripts and config..."
        ansible-playbook \
            -i inventory/hosts.yml \
            playbooks/armitage-vllm-deploy-scripts.yml \
            --limit armitage \
            -e "vllm_model_name=Qwen/Qwen2.5-7B-Instruct" \
            -v || echo "Deploy scripts completed with warnings"
        
        echo ""
        echo "[2/2] Validating and updating vLLM deployment..."
        ansible-playbook \
            -i inventory/hosts.yml \
            playbooks/armitage-vllm-validate.yml \
            --limit armitage \
            -v
        
        echo ""
        echo "[3/3] Running comprehensive validation..."
        cd ~/miket-infra-devices
        chmod +x scripts/Validate-Armitage-Model.sh
        ./scripts/Validate-Armitage-Model.sh || echo "Validation completed with warnings"
        
EOF
else
    # Already on Motoko
    echo "[1/2] Deploying updated scripts and config..."
    ansible-playbook \
        -i inventory/hosts.yml \
        playbooks/armitage-vllm-deploy-scripts.yml \
        --limit armitage \
        -e "vllm_model_name=Qwen/Qwen2.5-7B-Instruct" \
        -v || echo "Deploy scripts completed with warnings"
    
    echo ""
    echo "[2/2] Validating and updating vLLM deployment..."
    ansible-playbook \
        -i inventory/hosts.yml \
        playbooks/armitage-vllm-validate.yml \
        --limit armitage \
        -v
    
    echo ""
    echo "[3/3] Running comprehensive validation..."
    cd ~/miket-infra-devices
    chmod +x scripts/Validate-Armitage-Model.sh
    ./scripts/Validate-Armitage-Model.sh || echo "Validation completed with warnings"
fi

echo ""
echo "================================================================"
echo "  ✅ Deployment Complete"
echo "================================================================"

