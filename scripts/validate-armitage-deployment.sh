#!/bin/bash
# Copyright (c) 2025 MikeT LLC. All rights reserved.

# Validation script for Armitage vLLM deployment
# Verifies Qwen2.5-7B-Instruct (fp16/bf16) is deployed correctly

set -euo pipefail

REPORT_FILE="${1:-artifacts/armitage-deploy-report.txt}"
mkdir -p artifacts

echo "=== Armitage vLLM Deployment Validation Report ===" > "$REPORT_FILE"
echo "Generated: $(date)" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_status() {
    local status=$1
    local msg=$2
    if [ "$status" = "OK" ]; then
        echo -e "${GREEN}✓${NC} $msg"
        echo "✓ $msg" >> "$REPORT_FILE"
    elif [ "$status" = "WARN" ]; then
        echo -e "${YELLOW}⚠${NC} $msg"
        echo "⚠ $msg" >> "$REPORT_FILE"
    else
        echo -e "${RED}✗${NC} $msg"
        echo "✗ $msg" >> "$REPORT_FILE"
    fi
}

# 1. Check Armitage vLLM container
echo "1. Checking Armitage vLLM container..."
if ansible armitage -i ansible/inventory/hosts.yml -m win_shell -a 'docker ps --filter name=vllm-armitage --format "{{.Names}}"' 2>/dev/null | grep -q vllm-armitage; then
    print_status "OK" "vLLM container is running"
    CONTAINER_STATUS=$(ansible armitage -i ansible/inventory/hosts.yml -m win_shell -a 'docker ps --filter name=vllm-armitage --format "{{.Status}}"' 2>/dev/null | tail -1)
    echo "  Container status: $CONTAINER_STATUS" >> "$REPORT_FILE"
else
    print_status "FAIL" "vLLM container is not running"
fi

# 2. Check vLLM API endpoint
echo "2. Checking vLLM API endpoint..."
ARMITAGE_URL="http://armitage.tailnet.local:8000"
if timeout 5 curl -s "$ARMITAGE_URL/v1/models" > /dev/null 2>&1; then
    print_status "OK" "vLLM API is accessible at $ARMITAGE_URL"
    MODELS_JSON=$(curl -s "$ARMITAGE_URL/v1/models" 2>/dev/null || echo '{"data":[]}')
    MODEL_ID=$(echo "$MODELS_JSON" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4 || echo "unknown")
    echo "  Model ID: $MODEL_ID" >> "$REPORT_FILE"
    
    # Check if model name contains Qwen (not AWQ)
    if echo "$MODEL_ID" | grep -qi "qwen" && ! echo "$MODEL_ID" | grep -qi "awq"; then
        print_status "OK" "Model appears to be non-quantized Qwen"
    elif echo "$MODEL_ID" | grep -qi "awq"; then
        print_status "FAIL" "Model is still AWQ quantized (should be fp16/bf16)"
    else
        print_status "WARN" "Could not verify model name from API"
    fi
else
    print_status "FAIL" "vLLM API is not accessible (may still be loading)"
fi

# 3. Check LiteLLM proxy
echo "3. Checking LiteLLM proxy..."
LITELLM_URL="http://localhost:8000"
if curl -s "$LITELLM_URL/v1/models" > /dev/null 2>&1; then
    print_status "OK" "LiteLLM proxy is accessible"
    LITELLM_MODELS=$(curl -s "$LITELLM_URL/v1/models" 2>/dev/null | grep -o '"id":"[^"]*"' | grep -i "qwen\|armitage" || echo "")
    if echo "$LITELLM_MODELS" | grep -q "qwen2.5-7b-armitage"; then
        print_status "OK" "LiteLLM has qwen2.5-7b-armitage model configured"
    else
        print_status "WARN" "LiteLLM model configuration may need verification"
    fi
else
    print_status "FAIL" "LiteLLM proxy is not accessible"
fi

# 4. Test completion endpoint
echo "4. Testing completion endpoint..."
TEST_PROMPT='{"model":"qwen2.5-7b-armitage","messages":[{"role":"user","content":"Say hello"}],"max_tokens":10}'
if RESPONSE=$(curl -s -X POST "$LITELLM_URL/v1/chat/completions" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer dummy" \
    -d "$TEST_PROMPT" 2>/dev/null); then
    if echo "$RESPONSE" | grep -q "choices"; then
        print_status "OK" "Completion endpoint works"
        LATENCY=$(echo "$RESPONSE" | grep -o '"created":[0-9]*' | head -1 || echo "")
        echo "  Test response received" >> "$REPORT_FILE"
    else
        print_status "WARN" "Completion endpoint returned unexpected response"
        echo "  Response: $RESPONSE" >> "$REPORT_FILE"
    fi
else
    print_status "WARN" "Could not test completion endpoint"
fi

# 5. Check Ansible connectivity
echo "5. Checking Ansible connectivity..."
if ansible armitage -i ansible/inventory/hosts.yml -m win_ping > /dev/null 2>&1; then
    print_status "OK" "Ansible can connect to Armitage"
else
    print_status "FAIL" "Ansible cannot connect to Armitage"
fi

# 6. Check configuration files
echo "6. Checking configuration files..."
if grep -q "Qwen/Qwen2.5-7B-Instruct" devices/armitage/config.yml && ! grep -q "AWQ" devices/armitage/config.yml; then
    print_status "OK" "Config file uses non-quantized model"
else
    print_status "FAIL" "Config file still references AWQ or wrong model"
fi

if grep -q "qwen2.5-7b-armitage" ansible/roles/litellm_proxy/templates/litellm.config.yaml.j2 && \
   grep -q "Qwen/Qwen2.5-7B-Instruct" ansible/roles/litellm_proxy/templates/litellm.config.yaml.j2 && \
   ! grep -q "AWQ" ansible/roles/litellm_proxy/templates/litellm.config.yaml.j2; then
    print_status "OK" "LiteLLM config uses non-quantized model"
else
    print_status "FAIL" "LiteLLM config still references AWQ"
fi

echo "" >> "$REPORT_FILE"
echo "=== Summary ===" >> "$REPORT_FILE"
echo "Validation completed: $(date)" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo "Full report saved to: $REPORT_FILE"
cat "$REPORT_FILE"

