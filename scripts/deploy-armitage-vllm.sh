#!/bin/bash
# Deploy vLLM to Armitage with enhanced observability
# Run from motoko control node

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANSIBLE_DIR="${SCRIPT_DIR}/ansible"

cd "${ANSIBLE_DIR}"

echo "================================================================"
echo "  Armitage vLLM Deployment"
echo "================================================================"
echo ""
echo "This script will deploy vLLM to Armitage with:"
echo "  - Enhanced WinRM timeout handling"
echo "  - Real-time progress tracking"
echo "  - Detailed logging"
echo ""
echo "Press Ctrl+C to cancel, or Enter to continue..."
read -r

# Check if vault password is needed
if [ ! -f .vault_pass ]; then
    echo ""
    echo "Vault password file not found. You'll be prompted for the vault password."
    echo ""
    VAULT_FLAG="--ask-vault-pass"
else
    VAULT_FLAG="--vault-password-file .vault_pass"
fi

# Run with verbose output and timing
echo ""
echo "Starting deployment at $(date '+%Y-%m-%d %H:%M:%S')..."
echo "================================================================"
echo ""

ansible-playbook \
    -i inventory/hosts.yml \
    playbooks/armitage-vllm-setup.yml \
    --limit armitage \
    ${VAULT_FLAG} \
    -v \
    --diff \
    "$@"

EXIT_CODE=$?

echo ""
echo "================================================================"
if [ $EXIT_CODE -eq 0 ]; then
    echo "✅ Deployment completed successfully at $(date '+%Y-%m-%d %H:%M:%S')"
else
    echo "❌ Deployment failed with exit code $EXIT_CODE at $(date '+%Y-%m-%d %H:%M:%S')"
fi
echo "================================================================"

exit $EXIT_CODE


