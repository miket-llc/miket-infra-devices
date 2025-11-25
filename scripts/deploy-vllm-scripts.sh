#!/bin/bash
# Copyright (c) 2025 MikeT LLC. All rights reserved.

# Fast deployment - just vLLM scripts and config
# Assumes Docker Desktop is already set up manually

set -euo pipefail

cd /home/mdt/miket-infra-devices/ansible

echo "========================================"
echo "Deploying vLLM Scripts to Armitage"
echo "========================================"
echo ""

ansible-playbook \
    -i inventory/hosts.yml \
    playbooks/armitage-vllm-deploy-scripts.yml \
    --limit armitage \
    --vault-password-file ~/.ansible/vault_pass.txt \
    -e "ansible_password=MonkeyB0y" \
    -v

EXIT_CODE=$?

echo ""
if [ $EXIT_CODE -eq 0 ]; then
    echo "✅ Deployment complete!"
else
    echo "❌ Deployment failed"
fi

exit $EXIT_CODE

