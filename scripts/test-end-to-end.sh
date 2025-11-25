#!/bin/bash
# Copyright (c) 2025 MikeT LLC. All rights reserved.

# End-to-end test script that works with local services
# Tests LiteLLM proxy and validates configuration

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

echo "=========================================="
echo "End-to-End Validation Test"
echo "=========================================="
echo ""

# Test LiteLLM proxy
echo "=== Testing LiteLLM Proxy ==="
LITELLM_URL="http://localhost:8000"

if curl -s -f "$LITELLM_URL/health" >/dev/null 2>&1; then
    echo "✓ LiteLLM proxy is running"
    
    # Get available models
    echo ""
    echo "Available models:"
    MODELS=$(curl -s "$LITELLM_URL/v1/models" 2>/dev/null)
    if [ -n "$MODELS" ]; then
        echo "$MODELS" | python3 -m json.tool 2>/dev/null | grep -E '"id"|"model_name"' | head -10 || echo "$MODELS" | head -20
    else
        echo "  Could not retrieve models list"
    fi
    
    # Test a simple request
    echo ""
    echo "=== Testing Chat Completion ==="
    
    # Check if we have a token
    if [ -z "$LITELLM_TOKEN" ]; then
        echo "⚠ LITELLM_TOKEN not set - some tests may fail"
    fi
    
    # Try to make a test request
    TEST_PAYLOAD='{
        "model": "local/chat",
        "messages": [{"role": "user", "content": "Say hello"}],
        "max_tokens": 10
    }'
    
    HEADERS=(-H "Content-Type: application/json")
    if [ -n "$LITELLM_TOKEN" ]; then
        HEADERS+=(-H "Authorization: Bearer $LITELLM_TOKEN")
    fi
    
    RESPONSE=$(curl -s -w "\n%{http_code}" "${HEADERS[@]}" -d "$TEST_PAYLOAD" "$LITELLM_URL/v1/chat/completions" 2>&1)
    HTTP_CODE=$(echo "$RESPONSE" | tail -1)
    BODY=$(echo "$RESPONSE" | sed '$d')
    
    if [ "$HTTP_CODE" = "200" ]; then
        echo "✓ Test request successful"
        echo "$BODY" | python3 -m json.tool 2>/dev/null | head -15 || echo "$BODY" | head -10
    elif [ "$HTTP_CODE" = "401" ] || [ "$HTTP_CODE" = "403" ]; then
        echo "⚠ Authentication required (HTTP $HTTP_CODE)"
        echo "  Set LITELLM_TOKEN environment variable"
    elif [ "$HTTP_CODE" = "503" ] || [ "$HTTP_CODE" = "502" ]; then
        echo "⚠ Backend service unavailable (HTTP $HTTP_CODE)"
        echo "  vLLM services may not be running"
    else
        echo "✗ Test request failed (HTTP $HTTP_CODE)"
        echo "$BODY" | head -5
    fi
    
else
    echo "✗ LiteLLM proxy is not running"
    echo "  Start it with: sudo systemctl start litellm"
    echo "  Or check: sudo systemctl status litellm"
fi

# Check vLLM containers
echo ""
echo "=== Checking vLLM Containers ==="
VLLM_CONTAINERS=$(docker ps --filter "name=vllm" --format "{{.Names}}" 2>/dev/null || echo "")

if [ -n "$VLLM_CONTAINERS" ]; then
    echo "Found vLLM containers:"
    for container in $VLLM_CONTAINERS; do
        echo "  - $container"
        STATUS=$(docker inspect --format='{{.State.Status}}' "$container" 2>/dev/null || echo "unknown")
        echo "    Status: $STATUS"
        
        # Check logs for configuration
        echo "    Recent log entries:"
        docker logs "$container" --tail 5 2>&1 | grep -iE "max-model-len|kv-cache|max-num-seqs|error|ready" | head -3 || echo "      (no relevant log entries)"
    done
else
    echo "No vLLM containers running"
    echo "  Deploy with: make deploy-wintermute deploy-armitage"
    echo "  Or manually on each device"
fi

# Summary
echo ""
echo "=========================================="
echo "Validation Summary"
echo "=========================================="

if curl -s -f "$LITELLM_URL/health" >/dev/null 2>&1; then
    echo "✓ LiteLLM proxy: Running"
else
    echo "✗ LiteLLM proxy: Not running"
fi

if [ -n "$VLLM_CONTAINERS" ]; then
    echo "✓ vLLM containers: Found ($(echo $VLLM_CONTAINERS | wc -w) running)"
else
    echo "✗ vLLM containers: None running"
fi

echo ""
echo "Next steps:"
if [ -z "$VLLM_CONTAINERS" ]; then
    echo "1. Deploy vLLM services on Wintermute and Armitage"
    echo "2. Restart LiteLLM proxy if configuration changed"
fi
echo "3. Run full tests: make test-context test-burst"
echo "4. Monitor: docker logs <container-name> -f"

