#!/bin/bash
# Comprehensive validation and troubleshooting script
# Tests deployment readiness and provides diagnostics

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

echo "=========================================="
echo "vLLM Deployment Validation & Diagnostics"
echo "=========================================="
echo ""

# Check if we're on a device that can run vLLM
IS_WINDOWS=false
IS_LINUX=false

if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" || -n "$WSL_DISTRO_NAME" ]]; then
    IS_WINDOWS=true
    echo "✓ Detected Windows/WSL2 environment"
fi

if [[ "$OSTYPE" == "linux-gnu"* && -z "$WSL_DISTRO_NAME" ]]; then
    IS_LINUX=true
    echo "✓ Detected Linux environment"
fi

# Check Docker availability
echo ""
echo "=== Docker Check ==="
if command -v docker >/dev/null 2>&1; then
    echo "✓ Docker is installed"
    if docker ps >/dev/null 2>&1; then
        echo "✓ Docker daemon is running"
        
        # Check for vLLM containers
        echo ""
        echo "Current vLLM containers:"
        docker ps --filter "name=vllm" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" || echo "  No vLLM containers running"
        
        # Check GPU access
        echo ""
        echo "=== GPU Check ==="
        if docker run --rm --gpus all nvidia/cuda:12.0.0-base-ubuntu22.04 nvidia-smi >/dev/null 2>&1; then
            echo "✓ GPU access available in Docker"
            docker run --rm --gpus all nvidia/cuda:12.0.0-base-ubuntu22.04 nvidia-smi --query-gpu=name,memory.total --format=csv,noheader | head -1
        else
            echo "✗ GPU access not available in Docker"
            echo "  This may be expected if not on a GPU-enabled device"
        fi
    else
        echo "✗ Docker daemon is not running"
        echo "  Start Docker Desktop (Windows) or docker service (Linux)"
    fi
else
    echo "✗ Docker is not installed"
fi

# Check configuration files
echo ""
echo "=== Configuration Files ==="
if [ -f "devices/wintermute/config.yml" ]; then
    echo "✓ Wintermute config exists"
    if grep -q "max_model_len: 16384" devices/wintermute/config.yml; then
        echo "  ✓ max_model_len: 16384"
    else
        echo "  ✗ max_model_len not set correctly"
    fi
else
    echo "✗ Wintermute config not found"
fi

if [ -f "devices/armitage/config.yml" ]; then
    echo "✓ Armitage config exists"
    if grep -q "max_model_len: 8192" devices/armitage/config.yml; then
        echo "  ✓ max_model_len: 8192"
    else
        echo "  ✗ max_model_len not set correctly"
    fi
else
    echo "✗ Armitage config not found"
fi

# Check scripts
echo ""
echo "=== Deployment Scripts ==="
if [ -f "devices/wintermute/scripts/Start-VLLM.ps1" ]; then
    echo "✓ Wintermute PowerShell script exists"
    if grep -q "max-num-seqs" devices/wintermute/scripts/Start-VLLM.ps1; then
        echo "  ✓ Contains new flags"
    fi
fi

if [ -f "devices/armitage/scripts/Start-VLLM.ps1" ]; then
    echo "✓ Armitage PowerShell script exists"
    if grep -q "max-num-seqs" devices/armitage/scripts/Start-VLLM.ps1; then
        echo "  ✓ Contains new flags"
    fi
fi

# Test API endpoints (if containers are running)
echo ""
echo "=== API Endpoint Tests ==="

# Check local vLLM if running
if docker ps --format '{{.Names}}' | grep -q "vllm-wintermute"; then
    echo "Testing Wintermute vLLM..."
    if curl -s -f http://localhost:8000/v1/models >/dev/null 2>&1; then
        echo "✓ Wintermute vLLM API is responding"
        curl -s http://localhost:8000/v1/models | python3 -m json.tool 2>/dev/null | head -10 || echo "  Response received"
    else
        echo "✗ Wintermute vLLM API not responding"
    fi
fi

if docker ps --format '{{.Names}}' | grep -q "vllm-armitage"; then
    echo "Testing Armitage vLLM..."
    if curl -s -f http://localhost:8000/v1/models >/dev/null 2>&1; then
        echo "✓ Armitage vLLM API is responding"
    else
        echo "✗ Armitage vLLM API not responding"
    fi
fi

# Check LiteLLM proxy
if curl -s -f http://localhost:8000/health >/dev/null 2>&1; then
    echo "✓ LiteLLM proxy is responding (port 8000)"
elif curl -s -f http://motoko.tailnet.local:8000/health >/dev/null 2>&1; then
    echo "✓ LiteLLM proxy is responding (remote)"
else
    echo "✗ LiteLLM proxy not responding"
fi

# Deployment readiness
echo ""
echo "=== Deployment Readiness ==="
READY=true

if [ ! -f "devices/wintermute/config.yml" ]; then
    echo "✗ Wintermute config missing"
    READY=false
fi

if [ ! -f "devices/armitage/config.yml" ]; then
    echo "✗ Armitage config missing"
    READY=false
fi

if [ ! -f "Makefile" ]; then
    echo "✗ Makefile missing"
    READY=false
fi

if [ ! -d "tests" ]; then
    echo "✗ Tests directory missing"
    READY=false
fi

if [ "$READY" = true ]; then
    echo "✓ All configuration files present"
    echo ""
    echo "Ready to deploy! Next steps:"
    echo ""
    if [ "$IS_WINDOWS" = true ]; then
        echo "On Windows device:"
        echo "  1. cd devices/wintermute/scripts"
        echo "  2. .\\Start-VLLM.ps1 Restart"
        echo ""
        echo "Or on Armitage:"
        echo "  1. cd devices/armitage/scripts"
        echo "  2. .\\Start-VLLM.ps1 Restart"
    else
        echo "Deployment options:"
        echo "  1. Manual: SSH to each device and run Start-VLLM.ps1 Restart"
        echo "  2. Automated: make deploy-wintermute deploy-armitage"
        echo "  3. Test: make test-context test-burst"
    fi
else
    echo "✗ Not ready for deployment - fix issues above"
fi

echo ""
echo "=========================================="

