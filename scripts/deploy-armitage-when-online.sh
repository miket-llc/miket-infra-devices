#!/bin/bash
# Copyright (c) 2025 MikeT LLC. All rights reserved.

# Quick deployment script for Armitage when it comes online
# Run from motoko: ./scripts/deploy-armitage-when-online.sh

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_ROOT"

echo "================================================"
echo "  Deploying Armitage vLLM Configuration"
echo "================================================"
echo ""

# Test connectivity
echo "1. Testing connectivity to armitage..."
if ! ansible -i ansible/inventory/hosts.yml armitage -m win_ping > /dev/null 2>&1; then
    echo "❌ ERROR: Cannot reach armitage. Is it online and connected to Tailscale?"
    exit 1
fi
echo "✅ Armitage is reachable"
echo ""

# Deploy config
echo "2. Deploying config.yml (Qwen2.5-7B, 32k context)..."
ansible -i ansible/inventory/hosts.yml armitage -m win_copy \
  -a "src=devices/armitage/config.yml dest=C:\\Users\\mdt\\dev\\armitage\\config.yml" \
  -o | grep "SUCCESS\|CHANGED" && echo "✅ Config deployed" || echo "❌ Config deployment failed"
echo ""

# Deploy Start-VLLM script
echo "3. Deploying Start-VLLM.ps1..."
ansible -i ansible/inventory/hosts.yml armitage -m win_copy \
  -a "src=devices/armitage/scripts/Start-VLLM.ps1 dest=C:\\Users\\mdt\\dev\\armitage\\scripts\\Start-VLLM.ps1" \
  -o | grep "SUCCESS\|CHANGED" && echo "✅ Start script deployed" || echo "❌ Script deployment failed"
echo ""

# Deploy Auto-ModeSwitcher
echo "4. Deploying Auto-ModeSwitcher.ps1..."
ansible -i ansible/inventory/hosts.yml armitage -m win_copy \
  -a "src=devices/armitage/scripts/Auto-ModeSwitcher.ps1 dest=C:\\Users\\mdt\\dev\\armitage\\scripts\\Auto-ModeSwitcher.ps1" \
  -o | grep "SUCCESS\|CHANGED" && echo "✅ Auto-ModeSwitcher deployed" || echo "❌ Auto-ModeSwitcher deployment failed"
echo ""

# Deploy Set-WorkstationMode
echo "5. Deploying Set-WorkstationMode.ps1..."
ansible -i ansible/inventory/hosts.yml armitage -m win_copy \
  -a "src=devices/armitage/scripts/Set-WorkstationMode.ps1 dest=C:\\Users\\mdt\\dev\\armitage\\scripts\\Set-WorkstationMode.ps1" \
  -o | grep "SUCCESS\|CHANGED" && echo "✅ Set-WorkstationMode deployed" || echo "❌ Set-WorkstationMode deployment failed"
echo ""

# Restart vLLM
echo "6. Restarting vLLM container with new configuration..."
ansible -i ansible/inventory/hosts.yml armitage -m win_shell \
  -a "docker rm -f vllm-armitage 2>&1 | Out-Null; powershell -ExecutionPolicy Bypass -File C:\Users\mdt\dev\armitage\scripts\Start-VLLM.ps1 -Action Start" \
  -o | grep "✅\|started successfully" && echo "✅ Container restart initiated" || echo "⚠️ Container restart may have issues - check logs"
echo ""

echo "================================================"
echo "  Waiting for Model to Load (2-3 minutes)"
echo "================================================"
echo ""
echo "The Qwen2.5-7B model needs to download and load into GPU memory."
echo "This typically takes 2-3 minutes on first run."
echo ""

for i in {1..30}; do
    echo "Health check $i/30..."
    if curl -s --max-time 3 http://armitage.pangolin-vega.ts.net:8000/health > /dev/null 2>&1; then
        echo ""
        echo "✅ Armitage vLLM is healthy!"
        echo ""
        echo "Testing models endpoint..."
        curl -s http://armitage.pangolin-vega.ts.net:8000/v1/models | python3 -m json.tool
        echo ""
        echo "================================================"
        echo "  ✅ DEPLOYMENT COMPLETE!"
        echo "================================================"
        echo ""
        echo "Next step: Restart LiteLLM proxy"
        echo "  docker restart litellm"
        echo ""
        echo "Then test end-to-end:"
        echo "  curl http://motoko.pangolin-vega.ts.net:8000/health"
        echo ""
        exit 0
    fi
    sleep 10
done

echo ""
echo "⚠️  Model loading is taking longer than expected."
echo "Check logs: ansible -i ansible/inventory/hosts.yml armitage -m win_shell -a 'docker logs vllm-armitage --tail 50'"
echo ""

