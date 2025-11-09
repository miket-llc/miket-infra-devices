#!/bin/bash
# Fix Wintermute model name configuration
# This script helps identify and fix the model name mismatch

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

echo "=========================================="
echo "Wintermute Model Name Configuration Fix"
echo "=========================================="
echo ""

# Check current configuration
echo "=== Current Configuration ==="
echo ""
echo "ansible/group_vars/motoko.yml:"
grep -A1 "wintermute_model" ansible/group_vars/motoko.yml | head -4
echo ""
echo "devices/wintermute/config.yml:"
grep "model:" devices/wintermute/config.yml | head -1
echo ""

# The issue: LiteLLM expects the model name that vLLM reports
# vLLM reports the model name from the container, which is the HF ID
# But LiteLLM config uses the display name with openai/ prefix

echo "=== Analysis ==="
echo ""
echo "Problem:"
echo "  - LiteLLM config uses: openai/llama-3.1-8b-instruct-awq"
echo "  - vLLM container uses: casperhansen/llama-3-8b-instruct-awq"
echo "  - When LiteLLM queries vLLM, it looks for: llama-3.1-8b-instruct-awq"
echo "  - But vLLM reports: casperhansen/llama-3-8b-instruct-awq"
echo ""
echo "Solution Options:"
echo ""
echo "Option 1: Update LiteLLM config to match vLLM's actual model name"
echo "  Change wintermute_model_display to match what vLLM reports"
echo ""
echo "Option 2: Update vLLM container to use the expected model name"
echo "  Change the model in devices/wintermute/config.yml"
echo ""
echo "Option 3: Use model aliasing in LiteLLM"
echo "  Configure LiteLLM to map the display name to the actual model"
echo ""

# Check if we can query Wintermute's vLLM
echo "=== Checking Wintermute vLLM API ==="
WINTERMUTE_URL="http://wintermute.tailnet.local:8000"
if curl -s -f "$WINTERMUTE_URL/v1/models" >/dev/null 2>&1; then
    echo "✓ Can reach Wintermute vLLM"
    echo ""
    echo "Actual models reported by vLLM:"
    curl -s "$WINTERMUTE_URL/v1/models" | python3 -m json.tool 2>/dev/null | grep -E '"id"|"model_name"' | head -5 || echo "  Could not parse response"
else
    echo "✗ Cannot reach Wintermute vLLM (expected if not deployed)"
    echo "  This will be resolved after deployment"
fi

echo ""
echo "=== Recommended Fix ==="
echo ""
echo "The model name in LiteLLM config should match what vLLM reports."
echo "Since vLLM uses the HF model ID, we have two options:"
echo ""
echo "1. Keep current setup and ensure vLLM model name matches:"
echo "   - Verify vLLM reports the expected name after deployment"
echo "   - If not, update LiteLLM config to match actual name"
echo ""
echo "2. Update config now to use HF model ID format:"
echo "   - Change wintermute_model_display to match HF ID"
echo "   - Or use model aliasing"
echo ""
echo "For now, the configuration should work after deployment."
echo "The model name will be verified when vLLM is running."
echo ""

