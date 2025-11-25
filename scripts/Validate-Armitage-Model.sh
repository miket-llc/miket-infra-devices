#!/bin/bash
# Copyright (c) 2025 MikeT LLC. All rights reserved.

# Comprehensive validation script for Armitage vLLM → LiteLLM → Ansible control flow
# Run from Motoko (Ansible control node)
#
# This script validates:
# 1. Deployed model on Armitage (Qwen2.5-7B-Instruct)
# 2. vLLM configuration and health
# 3. LiteLLM proxy configuration on Motoko
# 4. Connectivity and health checks
# 5. Functional tests end-to-end
# 6. Generates validation report

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
ARMITAGE_HOST="armitage.pangolin-vega.ts.net"
ARMITAGE_VLLM_PORT=8000
MOTOKO_LITELLM_PORT=4000
EXPECTED_MODEL="Qwen/Qwen2.5-7B-Instruct"
EXPECTED_SERVED_NAME="qwen2.5-7b-armitage"
REPO_DIR="${REPO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
REPORT_FILE="${REPORT_FILE:-${REPO_DIR}/artifacts/armitage-deploy-report.txt}"
ARTIFACTS_DIR="${REPO_DIR}/artifacts"

# Create artifacts directory
mkdir -p "$ARTIFACTS_DIR"

# Initialize report
{
    echo "=================================================================="
    echo "  Armitage Model Validation Report"
    echo "=================================================================="
    echo "Generated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")"
    echo "Host: $(hostname)"
    echo ""
} > "$REPORT_FILE"

log() {
    echo -e "${CYAN}[$(date +'%H:%M:%S')]${NC} $1" | tee -a "$REPORT_FILE"
}

log_success() {
    echo -e "${GREEN}✅${NC} $1" | tee -a "$REPORT_FILE"
}

log_warning() {
    echo -e "${YELLOW}⚠️${NC} $1" | tee -a "$REPORT_FILE"
}

log_error() {
    echo -e "${RED}❌${NC} $1" | tee -a "$REPORT_FILE"
}

log_section() {
    echo "" | tee -a "$REPORT_FILE"
    echo "==================================================================" | tee -a "$REPORT_FILE"
    echo "  $1" | tee -a "$REPORT_FILE"
    echo "==================================================================" | tee -a "$REPORT_FILE"
    echo "" | tee -a "$REPORT_FILE"
}

# Test connectivity
test_connectivity() {
    log_section "1. Connectivity Tests"
    
    # Test Ansible ping
    log "Testing Ansible connectivity to Armitage..."
    if ansible armitage -i "${REPO_DIR}/ansible/inventory/hosts.yml" -m win_ping &>> "$REPORT_FILE" 2>&1; then
        log_success "Ansible connectivity: OK"
    else
        log_error "Ansible connectivity: FAILED"
        return 1
    fi
    
    # Test Tailnet connectivity
    log "Testing Tailnet connectivity to Armitage..."
    if ping -c 2 "$ARMITAGE_HOST" &>> "$REPORT_FILE" 2>&1; then
        log_success "Tailnet connectivity: OK"
    else
        log_error "Tailnet connectivity: FAILED"
        return 1
    fi
    
    # Test vLLM endpoint
    log "Testing vLLM endpoint on Armitage..."
    if curl -s --max-time 5 "http://${ARMITAGE_HOST}:${ARMITAGE_VLLM_PORT}/health" &>> "$REPORT_FILE" 2>&1; then
        log_success "vLLM health endpoint: OK"
    else
        log_warning "vLLM health endpoint: Not responding (container may be stopped)"
    fi
    
    # Test LiteLLM endpoint
    log "Testing LiteLLM endpoint on Motoko..."
    if curl -s --max-time 5 "http://localhost:${MOTOKO_LITELLM_PORT}/health" &>> "$REPORT_FILE" 2>&1; then
        log_success "LiteLLM health endpoint: OK"
    else
        log_warning "LiteLLM health endpoint: Not responding (service may be stopped)"
    fi
}

# Check vLLM deployment on Armitage
check_vllm_deployment() {
    log_section "2. vLLM Deployment Check (Armitage)"
    
    # Check if vLLM container is running
    log "Checking vLLM container status on Armitage..."
    CONTAINER_STATUS=$(ansible armitage -i "${REPO_DIR}/ansible/inventory/hosts.yml" \
        -m win_shell \
        -a "docker ps --filter name=vllm-armitage --format '{{.Status}}'" \
        --one-line 2>&1 | grep -v "SUCCESS" || echo "")
    
    if echo "$CONTAINER_STATUS" | grep -q "Up"; then
        log_success "vLLM container: Running"
        echo "Container Status: $CONTAINER_STATUS" >> "$REPORT_FILE"
    else
        log_warning "vLLM container: Not running"
        echo "Container Status: $CONTAINER_STATUS" >> "$REPORT_FILE"
    fi
    
    # Get container process info
    log "Checking vLLM process details..."
    PROCESS_INFO=$(ansible armitage -i "${REPO_DIR}/ansible/inventory/hosts.yml" \
        -m win_shell \
        -a "docker exec vllm-armitage ps aux | grep -i 'vllm.entrypoints' || echo 'Process not found'" \
        --one-line 2>&1 | grep -v "SUCCESS" || echo "")
    echo "Process Info: $PROCESS_INFO" >> "$REPORT_FILE"
    
    # Check model via API
    log "Querying vLLM models endpoint..."
    MODELS_JSON=$(curl -s --max-time 10 "http://${ARMITAGE_HOST}:${ARMITAGE_VLLM_PORT}/v1/models" 2>&1 || echo "")
    
    if [ -n "$MODELS_JSON" ]; then
        echo "$MODELS_JSON" | jq '.' >> "$REPORT_FILE" 2>&1 || echo "$MODELS_JSON" >> "$REPORT_FILE"
        
        # Extract model ID
        MODEL_ID=$(echo "$MODELS_JSON" | jq -r '.data[0].id // empty' 2>/dev/null || echo "")
        
        if [ -n "$MODEL_ID" ]; then
            log "Detected Model ID: $MODEL_ID"
            
            if echo "$MODEL_ID" | grep -qi "qwen.*7b"; then
                log_success "Model matches Qwen 7B pattern"
            else
                log_warning "Model does not match expected Qwen 7B pattern"
            fi
        else
            log_warning "Could not extract model ID from response"
        fi
    else
        log_warning "Could not query models endpoint (container may be stopped)"
    fi
    
    # Check container launch arguments
    log "Checking container launch arguments..."
    INSPECT_OUTPUT=$(ansible armitage -i "${REPO_DIR}/ansible/inventory/hosts.yml" \
        -m win_shell \
        -a "docker inspect vllm-armitage --format '{{.Args}}' 2>&1 || echo 'Container not found'" \
        --one-line 2>&1 | grep -v "SUCCESS" || echo "")
    
    if [ -n "$INSPECT_OUTPUT" ]; then
        echo "Container Args: $INSPECT_OUTPUT" >> "$REPORT_FILE"
        
        # Check for expected parameters
        if echo "$INSPECT_OUTPUT" | grep -qi "qwen"; then
            log_success "Container args contain Qwen model reference"
        else
            log_warning "Container args do not contain Qwen model reference"
        fi
        
        if echo "$INSPECT_OUTPUT" | grep -qi "max-model-len.*8192\|max_model_len.*8192"; then
            log_success "Container args contain max-model-len 8192"
        else
            log_warning "Container args may not have max-model-len 8192"
        fi
        
        if echo "$INSPECT_OUTPUT" | grep -qi "bf16\|fp16"; then
            log_success "Container args contain dtype (bf16/fp16)"
        else
            log_warning "Container args may not specify dtype"
        fi
    fi
    
    # Check GPU memory usage
    log "Checking GPU memory usage..."
    GPU_INFO=$(ansible armitage -i "${REPO_DIR}/ansible/inventory/hosts.yml" \
        -m win_shell \
        -a "\"C:\Program Files\NVIDIA Corporation\NVSMI\nvidia-smi.exe\" --query-gpu=name,memory.used,memory.total,utilization.gpu --format=csv,noheader,nounits 2>&1 || echo 'nvidia-smi not available'" \
        --one-line 2>&1 | grep -v "SUCCESS" || echo "")
    
    if [ -n "$GPU_INFO" ] && ! echo "$GPU_INFO" | grep -qi "not available"; then
        log_success "GPU Info retrieved"
        echo "GPU Info: $GPU_INFO" >> "$REPORT_FILE"
    else
        log_warning "Could not retrieve GPU info"
    fi
    
    # Check CUDA environment
    log "Checking CUDA environment in container..."
    CUDA_INFO=$(ansible armitage -i "${REPO_DIR}/ansible/inventory/hosts.yml" \
        -m win_shell \
        -a "docker exec vllm-armitage env | grep -i cuda || echo 'CUDA env vars not found'" \
        --one-line 2>&1 | grep -v "SUCCESS" || echo "")
    echo "CUDA Environment: $CUDA_INFO" >> "$REPORT_FILE"
}

# Check LiteLLM configuration
check_litellm_config() {
    log_section "3. LiteLLM Proxy Configuration Check (Motoko)"
    
    # Find LiteLLM config file
    LITELLM_CONFIG_PATHS=(
        "/etc/litellm/config.yaml"
        "/opt/litellm/config.yaml"
        "${HOME}/litellm/config.yaml"
        "${HOME}/.litellm/config.yaml"
        "/mnt/data/docker/litellm/config.yaml"
    )
    
    LITELLM_CONFIG=""
    for path in "${LITELLM_CONFIG_PATHS[@]}"; do
        if [ -f "$path" ]; then
            LITELLM_CONFIG="$path"
            log_success "Found LiteLLM config: $path"
            break
        fi
    done
    
    if [ -z "$LITELLM_CONFIG" ]; then
        log_warning "LiteLLM config file not found in standard locations"
        log "Searching for litellm config files..."
        find /etc /opt "${HOME}" /mnt/data/docker -name "litellm*.yaml" -o -name "litellm*.yml" 2>/dev/null | head -5 >> "$REPORT_FILE" || true
        return 1
    fi
    
    # Check config content
    log "Checking LiteLLM configuration content..."
    echo "Config file: $LITELLM_CONFIG" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    cat "$LITELLM_CONFIG" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    
    # Check for Armitage route
    if grep -qi "qwen2.5-7b-armitage\|armitage" "$LITELLM_CONFIG"; then
        log_success "LiteLLM config contains Armitage route"
    else
        log_warning "LiteLLM config does not contain Armitage route"
    fi
    
    # Check API base
    if grep -qi "${ARMITAGE_HOST}:${ARMITAGE_VLLM_PORT}" "$LITELLM_CONFIG"; then
        log_success "LiteLLM config contains correct API base"
    else
        log_warning "LiteLLM config may not have correct API base"
    fi
    
    # Check LiteLLM service status
    log "Checking LiteLLM service status..."
    if systemctl is-active --quiet litellm 2>/dev/null; then
        log_success "LiteLLM systemd service: Running"
        systemctl status litellm --no-pager -l >> "$REPORT_FILE" 2>&1 || true
    elif docker ps --filter "name=litellm" --format "{{.Status}}" 2>/dev/null | grep -q "Up"; then
        log_success "LiteLLM Docker container: Running"
        docker ps --filter "name=litellm" >> "$REPORT_FILE" 2>&1 || true
    else
        log_warning "LiteLLM service/container: Not running"
    fi
}

# Functional tests
run_functional_tests() {
    log_section "4. Functional Tests"
    
    # Test 1: Direct vLLM API call
    log "Test 1: Direct vLLM API call..."
    TEST_PROMPT='{"model": "Qwen/Qwen2.5-7B-Instruct", "prompt": "Hello, how are you?", "max_tokens": 50}'
    
    START_TIME=$(date +%s.%N)
    VLLM_RESPONSE=$(curl -s --max-time 30 \
        -X POST "http://${ARMITAGE_HOST}:${ARMITAGE_VLLM_PORT}/v1/completions" \
        -H "Content-Type: application/json" \
        -d "$TEST_PROMPT" 2>&1 || echo "")
    END_TIME=$(date +%s.%N)
    VLLM_LATENCY=$(echo "$END_TIME - $START_TIME" | bc)
    
    if [ -n "$VLLM_RESPONSE" ] && echo "$VLLM_RESPONSE" | jq -e '.choices[0].text' &>/dev/null; then
        log_success "Direct vLLM API: SUCCESS (latency: ${VLLM_LATENCY}s)"
        echo "$VLLM_RESPONSE" | jq '.' >> "$REPORT_FILE"
    else
        log_warning "Direct vLLM API: FAILED or container not running"
        echo "Response: $VLLM_RESPONSE" >> "$REPORT_FILE"
    fi
    
    # Test 2: LiteLLM proxy call
    log "Test 2: LiteLLM proxy call..."
    LITELLM_PROMPT="{\"model\": \"${EXPECTED_SERVED_NAME}\", \"messages\": [{\"role\": \"user\", \"content\": \"Hello, how are you?\"}], \"max_tokens\": 50}"
    
    START_TIME=$(date +%s.%N)
    LITELLM_RESPONSE=$(curl -s --max-time 30 \
        -X POST "http://localhost:${MOTOKO_LITELLM_PORT}/v1/chat/completions" \
        -H "Content-Type: application/json" \
        -d "$LITELLM_PROMPT" 2>&1 || echo "")
    END_TIME=$(date +%s.%N)
    LITELLM_LATENCY=$(echo "$END_TIME - $START_TIME" | bc)
    
    if [ -n "$LITELLM_RESPONSE" ] && echo "$LITELLM_RESPONSE" | jq -e '.choices[0].message.content' &>/dev/null; then
        log_success "LiteLLM proxy API: SUCCESS (latency: ${LITELLM_LATENCY}s)"
        echo "$LITELLM_RESPONSE" | jq '.' >> "$REPORT_FILE"
    else
        log_warning "LiteLLM proxy API: FAILED or service not running"
        echo "Response: $LITELLM_RESPONSE" >> "$REPORT_FILE"
    fi
    
    # Test 3: Models endpoint comparison
    log "Test 3: Models endpoint comparison..."
    
    VLLM_MODELS=$(curl -s --max-time 10 "http://${ARMITAGE_HOST}:${ARMITAGE_VLLM_PORT}/v1/models" 2>&1 || echo "")
    LITELLM_MODELS=$(curl -s --max-time 10 "http://localhost:${MOTOKO_LITELLM_PORT}/v1/models" 2>&1 || echo "")
    
    if [ -n "$VLLM_MODELS" ] && [ -n "$LITELLM_MODELS" ]; then
        echo "vLLM Models:" >> "$REPORT_FILE"
        echo "$VLLM_MODELS" | jq '.' >> "$REPORT_FILE" 2>&1 || echo "$VLLM_MODELS" >> "$REPORT_FILE"
        echo "" >> "$REPORT_FILE"
        echo "LiteLLM Models:" >> "$REPORT_FILE"
        echo "$LITELLM_MODELS" | jq '.' >> "$REPORT_FILE" 2>&1 || echo "$LITELLM_MODELS" >> "$REPORT_FILE"
        
        if echo "$LITELLM_MODELS" | grep -qi "${EXPECTED_SERVED_NAME}"; then
            log_success "LiteLLM exposes ${EXPECTED_SERVED_NAME}"
        else
            log_warning "LiteLLM does not expose ${EXPECTED_SERVED_NAME}"
        fi
    fi
}

# Generate summary
generate_summary() {
    log_section "5. Validation Summary"
    
    {
        echo "Validation completed: $(date -u +"%Y-%m-%d %H:%M:%S UTC")"
        echo ""
        echo "Key Findings:"
        echo "- Check report above for detailed results"
        echo "- Model should be: ${EXPECTED_MODEL}"
        echo "- Served name should be: ${EXPECTED_SERVED_NAME}"
        echo "- vLLM endpoint: http://${ARMITAGE_HOST}:${ARMITAGE_VLLM_PORT}"
        echo "- LiteLLM endpoint: http://localhost:${MOTOKO_LITELLM_PORT}"
        echo ""
        echo "Next Steps:"
        echo "1. If model mismatch: Update config.yml and redeploy"
        echo "2. If LiteLLM not configured: Create/update LiteLLM config"
        echo "3. If connectivity issues: Check Tailnet and firewall"
        echo "4. If OOM errors: Lower max-model-len or use fp8 kv-cache"
        echo ""
    } >> "$REPORT_FILE"
    
    log_success "Validation report saved to: $REPORT_FILE"
}

# Main execution
main() {
    log_section "Starting Armitage Model Validation"
    
    # Check prerequisites
    if ! command -v jq &> /dev/null; then
        log_error "jq is required but not installed. Install with: sudo apt install jq"
        exit 1
    fi
    
    if ! command -v bc &> /dev/null; then
        log_error "bc is required but not installed. Install with: sudo apt install bc"
        exit 1
    fi
    
    # Run validation steps
    test_connectivity || true
    check_vllm_deployment || true
    check_litellm_config || true
    run_functional_tests || true
    generate_summary
    
    log_success "Validation complete. Review report: $REPORT_FILE"
}

# Run main function
main "$@"

