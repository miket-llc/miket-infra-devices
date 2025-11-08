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

# Vault password is handled automatically via ansible.cfg (vault_identity_list)
# No need for --ask-vault-pass or --vault-password-file flags

# Run with verbose output and timing
echo ""
echo "Starting deployment at $(date '+%Y-%m-%d %H:%M:%S')..."
echo "================================================================"
echo ""

ansible-playbook \
    -i inventory/hosts.yml \
    playbooks/armitage-vllm-setup.yml \
    --limit armitage \
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


