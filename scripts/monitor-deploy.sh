#!/bin/bash
# Run Armitage vLLM deployment with real-time monitoring
set -euo pipefail

cd /home/mdt/miket-infra-devices/ansible

LOG_FILE="/tmp/armitage-deploy-$(date +%s).log"

echo "========================================"
echo "Armitage vLLM Deployment"
echo "Log: $LOG_FILE"
echo "========================================"
echo ""

# Start deployment in background, redirect to log
ansible-playbook \
    -i inventory/hosts.yml \
    playbooks/armitage-vllm-setup.yml \
    --limit armitage \
    --vault-password-file ~/.ansible/vault_pass.txt \
    -e "ansible_password=MonkeyB0y" \
    -v \
    2>&1 | tee "$LOG_FILE" &
DEPLOY_PID=$!

echo "Deployment started (PID: $DEPLOY_PID)"
echo "Press Ctrl+C to stop monitoring (deployment will continue)"
echo ""

# Monitor with useful output
LAST_LINE=0
while kill -0 $DEPLOY_PID 2>/dev/null; do
    sleep 3
    
    if [ ! -f "$LOG_FILE" ]; then
        continue
    fi
    
    CURRENT_LINES=$(wc -l < "$LOG_FILE" 2>/dev/null || echo 0)
    
    if [ "$CURRENT_LINES" -gt "$LAST_LINE" ]; then
        # Show new lines, filtering for important info
        tail -n +$((LAST_LINE + 1)) "$LOG_FILE" 2>/dev/null | while IFS= read -r line || [ -n "$line" ]; do
            # Always show task starts/completions
            if echo "$line" | grep -qE "TASK.*\[.*/11\]|PLAY RECAP|PLAY \[|fatal:|FAILED"; then
                echo "$line"
            # Show progress from PowerShell scripts
            elif echo "$line" | grep -qE "\[.*\] ⏳|\[.*\] ✅|\[.*\] ❌|Waiting for Docker|Docker ready|Installing Ubuntu|WSL2 configured|Starting Docker"; then
                echo "$line"
            # Show task results
            elif echo "$line" | grep -qE "changed:|ok:|skipping:"; then
                echo "$line"
            fi
        done
        LAST_LINE=$CURRENT_LINES
    fi
done

wait $DEPLOY_PID
EXIT_CODE=$?

echo ""
echo "========================================"
if [ $EXIT_CODE -eq 0 ]; then
    echo "✅ Deployment completed successfully"
    echo ""
    echo "Summary:"
    tail -50 "$LOG_FILE" | grep -E "TASK.*\[.*/11\]|PLAY RECAP" | tail -15
else
    echo "❌ Deployment failed (exit code: $EXIT_CODE)"
    echo ""
    echo "Last 30 lines:"
    tail -30 "$LOG_FILE"
fi
echo "========================================"
echo "Full log: $LOG_FILE"

exit $EXIT_CODE

