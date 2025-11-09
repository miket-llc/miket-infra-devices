#!/bin/bash
# Quick validation script for vLLM configuration updates
# Validates configuration files and provides deployment checklist

set -e

echo "=========================================="
echo "vLLM Configuration Validation"
echo "=========================================="
echo ""

# Check if required files exist
echo "✓ Checking required files..."
files=(
    "devices/wintermute/config.yml"
    "devices/wintermute/scripts/Start-VLLM.ps1"
    "devices/wintermute/scripts/vllm.sh"
    "devices/armitage/config.yml"
    "devices/armitage/scripts/Start-VLLM.ps1"
    "ansible/roles/litellm_proxy/templates/litellm.config.yaml.j2"
    "Makefile"
    "tests/context_smoke.py"
    "tests/burst_test.py"
)

for file in "${files[@]}"; do
    if [ -f "$file" ]; then
        echo "  ✓ $file"
    else
        echo "  ✗ MISSING: $file"
        exit 1
    fi
done

echo ""
echo "✓ Validating Wintermute configuration..."

# Check Wintermute config values
if grep -q "max_model_len: 16384" devices/wintermute/config.yml; then
    echo "  ✓ max_model_len: 16384"
else
    echo "  ✗ max_model_len not set to 16384"
fi

if grep -q "max_num_seqs: 2" devices/wintermute/config.yml; then
    echo "  ✓ max_num_seqs: 2"
else
    echo "  ✗ max_num_seqs not set to 2"
fi

if grep -q "kv_cache_dtype: \"fp8\"" devices/wintermute/config.yml; then
    echo "  ✓ kv_cache_dtype: fp8"
else
    echo "  ✗ kv_cache_dtype not set to fp8"
fi

echo ""
echo "✓ Validating Armitage configuration..."

# Check Armitage config values
if grep -q "max_model_len: 8192" devices/armitage/config.yml; then
    echo "  ✓ max_model_len: 8192"
else
    echo "  ✗ max_model_len not set to 8192"
fi

if grep -q "max_num_seqs: 1" devices/armitage/config.yml; then
    echo "  ✓ max_num_seqs: 1"
else
    echo "  ✗ max_num_seqs not set to 1"
fi

echo ""
echo "✓ Validating LiteLLM configuration..."

# Check LiteLLM throttling
if grep -q "tpm_limit: 120000" ansible/roles/litellm_proxy/templates/litellm.config.yaml.j2; then
    echo "  ✓ Wintermute TPM limit: 120000"
else
    echo "  ✗ Wintermute TPM limit not found"
fi

if grep -q "max_input_tokens: 14000" ansible/roles/litellm_proxy/templates/litellm.config.yaml.j2; then
    echo "  ✓ Wintermute max_input_tokens: 14000"
else
    echo "  ✗ Wintermute max_input_tokens not found"
fi

if grep -q "llama31-8b-wintermute-burst" ansible/roles/litellm_proxy/templates/litellm.config.yaml.j2; then
    echo "  ✓ Burst profile configured"
else
    echo "  ✗ Burst profile not found"
fi

echo ""
echo "✓ Checking PowerShell scripts for new flags..."

if grep -q "max-num-seqs" devices/wintermute/scripts/Start-VLLM.ps1 && \
   grep -q "kv-cache-dtype" devices/wintermute/scripts/Start-VLLM.ps1; then
    echo "  ✓ Wintermute PowerShell script has new flags"
else
    echo "  ✗ Wintermute PowerShell script missing new flags"
fi

if grep -q "max-num-seqs" devices/armitage/scripts/Start-VLLM.ps1 && \
   grep -q "kv-cache-dtype" devices/armitage/scripts/Start-VLLM.ps1; then
    echo "  ✓ Armitage PowerShell script has new flags"
else
    echo "  ✗ Armitage PowerShell script missing new flags"
fi

echo ""
echo "✓ Checking bash script..."

if grep -q "MAX_NUM_SEQS" devices/wintermute/scripts/vllm.sh && \
   grep -q "KV_CACHE_DTYPE" devices/wintermute/scripts/vllm.sh; then
    echo "  ✓ Wintermute bash script has new flags"
else
    echo "  ✗ Wintermute bash script missing new flags"
fi

echo ""
echo "=========================================="
echo "Validation Complete"
echo "=========================================="
echo ""
echo "Next Steps:"
echo "1. Backup configurations: make backup-configs"
echo "2. Deploy to Wintermute: make deploy-wintermute"
echo "3. Deploy to Armitage: make deploy-armitage"
echo "4. Deploy LiteLLM proxy: make deploy-proxy"
echo "5. Run tests: make test-context && make test-burst"
echo "6. Monitor: make health-check"
echo ""

