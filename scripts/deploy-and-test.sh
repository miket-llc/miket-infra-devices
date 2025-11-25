#!/bin/bash
# Copyright (c) 2025 MikeT LLC. All rights reserved.

# Deployment automation script with monitoring and validation
# Handles deployment, monitoring, testing, and troubleshooting

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

LOG_DIR="logs"
ARTIFACTS_DIR="artifacts"
mkdir -p "$LOG_DIR" "$ARTIFACTS_DIR"

LOG_FILE="$LOG_DIR/deployment-$(date +%Y%m%d_%H%M%S).log"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

log "=========================================="
log "vLLM Context Window Deployment"
log "=========================================="
log ""

# Step 1: Validate configurations
log "Step 1: Validating configurations..."
if ./scripts/validate-vllm-config.sh >> "$LOG_FILE" 2>&1; then
    log "✓ Configuration validation passed"
else
    log "✗ Configuration validation failed - check logs"
    exit 1
fi

# Step 2: Backup
log ""
log "Step 2: Backing up configurations..."
if make backup-configs >> "$LOG_FILE" 2>&1; then
    log "✓ Backups created"
else
    log "⚠ Warning: Backup failed, but continuing..."
fi

# Step 3: Deploy Wintermute
log ""
log "Step 3: Deploying Wintermute vLLM..."
log "Note: This may require manual execution on Wintermute if SSH is not configured"
log "Manual command: cd devices/wintermute/scripts && ./Start-VLLM.ps1 Restart"

# Try automated deployment (may fail if SSH not configured)
if make deploy-wintermute >> "$LOG_FILE" 2>&1; then
    log "✓ Wintermute deployment command executed"
else
    log "⚠ Automated deployment failed - manual deployment required"
    log "  See docs/DEPLOYMENT_CHECKLIST.md for manual steps"
fi

# Wait for service to start
log "Waiting 30 seconds for Wintermute service to start..."
sleep 30

# Step 4: Deploy Armitage
log ""
log "Step 4: Deploying Armitage vLLM..."
log "Note: This may require manual execution on Armitage if SSH is not configured"
log "Manual command: cd devices/armitage/scripts && ./Start-VLLM.ps1 Restart"

if make deploy-armitage >> "$LOG_FILE" 2>&1; then
    log "✓ Armitage deployment command executed"
else
    log "⚠ Automated deployment failed - manual deployment required"
fi

sleep 30

# Step 5: Deploy LiteLLM Proxy
log ""
log "Step 5: Deploying LiteLLM Proxy..."
if make deploy-proxy >> "$LOG_FILE" 2>&1; then
    log "✓ LiteLLM proxy deployment command executed"
else
    log "⚠ Automated deployment failed - manual deployment required"
    log "  On Motoko: sudo systemctl restart litellm"
fi

sleep 10

# Step 6: Health Checks
log ""
log "Step 6: Running health checks..."
HEALTH_LOG="$LOG_DIR/health-check-$(date +%Y%m%d_%H%M%S).log"
if make health-check >> "$HEALTH_LOG" 2>&1; then
    log "✓ Health checks passed"
else
    log "✗ Some health checks failed - see $HEALTH_LOG"
    log "  This may be expected if services are still starting"
fi

# Step 7: Context Window Test
log ""
log "Step 7: Running context window smoke test..."
TEST_LOG="$LOG_DIR/context-test-$(date +%Y%m%d_%H%M%S).log"
if timeout 600 python3 tests/context_smoke.py >> "$TEST_LOG" 2>&1; then
    log "✓ Context window test passed"
else
    log "✗ Context window test failed - see $TEST_LOG"
    log "  Check artifacts/context_test_results.csv for details"
fi

# Step 8: Burst Test
log ""
log "Step 8: Running burst load test..."
BURST_LOG="$LOG_DIR/burst-test-$(date +%Y%m%d_%H%M%S).log"
if timeout 300 python3 tests/burst_test.py >> "$BURST_LOG" 2>&1; then
    log "✓ Burst test passed"
else
    log "✗ Burst test failed - see $BURST_LOG"
    log "  Check artifacts/burst_test_results.csv for details"
fi

# Step 9: Summary
log ""
log "=========================================="
log "Deployment Summary"
log "=========================================="
log "Log file: $LOG_FILE"
log "Health check: $HEALTH_LOG"
log "Context test: $TEST_LOG"
log "Burst test: $BURST_LOG"
log ""
log "Next steps:"
log "1. Review logs in $LOG_DIR/"
log "2. Check test results in $ARTIFACTS_DIR/"
log "3. Monitor services: docker logs vllm-wintermute -f"
log "4. If issues found, see docs/vLLM_CONTEXT_WINDOW_GUIDE.md"
log ""

