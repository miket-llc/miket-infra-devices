#!/bin/bash
# Copyright (c) 2025 MikeT LLC. All rights reserved.
#
# Health Check Script for vLLM Backends
# Tests connectivity and basic functionality of all AI Fabric nodes
#
# Usage:
#   ./check_vllm_backends.sh             # Check all backends
#   ./check_vllm_backends.sh motoko      # Check specific backend
#   ./check_vllm_backends.sh --json      # Output JSON

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Backend definitions (hostname:port:role)
declare -a BACKENDS=(
    "motoko:8200:embeddings-general:BAAI/bge-base-en-v1.5"
    "wintermute.pangolin-vega.ts.net:8000:chat-deep:llama31-8b-wintermute"
    "armitage.pangolin-vega.ts.net:8000:chat-fast:qwen2.5-7b-armitage"
)

# LiteLLM proxy
LITELLM_URL="http://127.0.0.1:8000"
LITELLM_TOKEN="${LITELLM_TOKEN:-$(sudo cat /podman/apps/litellm/.env 2>/dev/null | grep LITELLM_TOKEN | cut -d= -f2)}"

OUTPUT_JSON=false
FILTER_BACKEND=""
OVERALL_STATUS=0

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --json)
            OUTPUT_JSON=true
            shift
            ;;
        *)
            FILTER_BACKEND="$1"
            shift
            ;;
    esac
done

# Function to check a vLLM backend
check_backend() {
    local hostname=$1
    local port=$2
    local role=$3
    local expected_model=$4
    
    local url="http://${hostname}:${port}"
    local status="UNKNOWN"
    local message=""
    local latency=""
    
    # Check health endpoint
    if curl -s -m 5 "${url}/health" >/dev/null 2>&1; then
        # Check models endpoint
        local model_id=$(curl -s -m 5 "${url}/v1/models" | jq -r '.data[0].id' 2>/dev/null || echo "")
        
        if [[ -n "$model_id" ]]; then
            status="OK"
            message="Model: ${model_id}"
            
            # Measure latency with a tiny completion request (for chat models) or embeddings (for embedding models)
            local start_time=$(date +%s%N)
            if [[ "$role" == *"embedding"* ]]; then
                # Test embedding endpoint
                curl -s -m 10 "${url}/v1/embeddings" \
                    -H "Content-Type: application/json" \
                    -d '{"input":"test","model":"'"${model_id}"'"}' >/dev/null 2>&1 && {
                    local end_time=$(date +%s%N)
                    latency=$(( (end_time - start_time) / 1000000 ))
                    message="${message}, Latency: ${latency}ms"
                }
            else
                # Test chat completion endpoint
                curl -s -m 10 "${url}/v1/chat/completions" \
                    -H "Content-Type: application/json" \
                    -d '{"model":"'"${model_id}"'","messages":[{"role":"user","content":"hi"}],"max_tokens":5}' >/dev/null 2>&1 && {
                    local end_time=$(date +%s%N)
                    latency=$(( (end_time - start_time) / 1000000 ))
                    message="${message}, Latency: ${latency}ms"
                }
            fi
        else
            status="DEGRADED"
            message="Health OK but /v1/models failed"
        fi
    else
        status="DOWN"
        message="Health endpoint unreachable"
        OVERALL_STATUS=1
    fi
    
    # Output results
    if $OUTPUT_JSON; then
        echo "{\"backend\":\"${hostname}\",\"port\":${port},\"role\":\"${role}\",\"status\":\"${status}\",\"message\":\"${message}\",\"latency_ms\":${latency:-null}}"
    else
        local color=$GREEN
        [[ "$status" == "DOWN" ]] && color=$RED
        [[ "$status" == "DEGRADED" ]] && color=$YELLOW
        
        printf "${color}%-40s %-15s %-10s${NC} %s\n" "${hostname}:${port}" "$role" "$status" "$message"
    fi
}

# Function to check litellm proxy
check_litellm() {
    local status="UNKNOWN"
    local message=""
    local model_count=0
    
    if curl -s -m 5 "${LITELLM_URL}/health" >/dev/null 2>&1; then
        model_count=$(curl -s -m 5 -H "Authorization: Bearer ${LITELLM_TOKEN}" "${LITELLM_URL}/v1/models" | jq -r '.data | length' 2>/dev/null || echo "0")
        
        if [[ "$model_count" -gt 0 ]]; then
            status="OK"
            message="${model_count} models available"
        else
            status="DEGRADED"
            message="No models available"
        fi
    else
        status="DOWN"
        message="LiteLLM proxy unreachable"
        OVERALL_STATUS=1
    fi
    
    if $OUTPUT_JSON; then
        echo "{\"backend\":\"litellm-proxy\",\"port\":8000,\"role\":\"gateway\",\"status\":\"${status}\",\"message\":\"${message}\",\"model_count\":${model_count}}"
    else
        local color=$GREEN
        [[ "$status" == "DOWN" ]] && color=$RED
        [[ "$status" == "DEGRADED" ]] && color=$YELLOW
        
        printf "${color}%-40s %-15s %-10s${NC} %s\n" "litellm-proxy:8000" "gateway" "$status" "$message"
    fi
}

# Main execution
if $OUTPUT_JSON; then
    echo "{"
    echo "  \"timestamp\": \"$(date -Iseconds)\","
    echo "  \"backends\": ["
fi

if ! $OUTPUT_JSON; then
    echo "========================================"
    echo "AI Fabric Backend Health Check"
    echo "========================================"
    printf "%-40s %-15s %-10s %s\n" "BACKEND" "ROLE" "STATUS" "DETAILS"
    echo "----------------------------------------"
fi

# Check LiteLLM proxy first
check_litellm
if $OUTPUT_JSON; then
    echo ","
fi

# Check each backend
for i in "${!BACKENDS[@]}"; do
    IFS=':' read -r hostname port role model <<< "${BACKENDS[$i]}"
    
    # Skip if filtering and doesn't match
    if [[ -n "$FILTER_BACKEND" ]] && [[ ! "$hostname" =~ $FILTER_BACKEND ]]; then
        continue
    fi
    
    check_backend "$hostname" "$port" "$role" "$model"
    
    # Add comma for JSON output (except last element)
    if $OUTPUT_JSON && [[ $i -lt $(( ${#BACKENDS[@]} - 1 )) ]]; then
        echo ","
    fi
done

if $OUTPUT_JSON; then
    echo "  ],"
    echo "  \"overall_status\": \"$( [[ $OVERALL_STATUS -eq 0 ]] && echo OK || echo DEGRADED )\""
    echo "}"
else
    echo "========================================"
    if [[ $OVERALL_STATUS -eq 0 ]]; then
        echo -e "${GREEN}✓ All backends healthy${NC}"
    else
        echo -e "${RED}✗ Some backends are down${NC}"
    fi
fi

exit $OVERALL_STATUS

