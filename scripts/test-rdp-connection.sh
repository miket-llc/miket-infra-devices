#!/bin/bash
# Test RDP connectivity to Windows devices
# This script tests if RDP is accessible on the configured port

set -e

HOST="${1:-armitage}"
PORT="${2:-3389}"
TAILNET_HOSTNAME="${HOST}.pangolin-vega.ts.net"

echo "Testing RDP connectivity to $TAILNET_HOSTNAME:$PORT..."
echo ""

# Test if port is open
if command -v nc >/dev/null 2>&1; then
    echo "Testing port connectivity with netcat..."
    if timeout 5 nc -z "$TAILNET_HOSTNAME" "$PORT" 2>/dev/null; then
        echo "✅ Port $PORT is open on $TAILNET_HOSTNAME"
    else
        echo "❌ Port $PORT is not accessible on $TAILNET_HOSTNAME"
        echo "   This could mean:"
        echo "   - RDP service is not running"
        echo "   - Firewall is blocking the connection"
        echo "   - Device is offline"
        exit 1
    fi
elif command -v telnet >/dev/null 2>&1; then
    echo "Testing port connectivity with telnet..."
    if timeout 5 telnet "$TAILNET_HOSTNAME" "$PORT" </dev/null 2>/dev/null | grep -q "Connected"; then
        echo "✅ Port $PORT is open on $TAILNET_HOSTNAME"
    else
        echo "❌ Port $PORT is not accessible on $TAILNET_HOSTNAME"
        exit 1
    fi
else
    echo "⚠️  netcat or telnet not found, skipping port test"
    echo "   Install with: sudo apt-get install netcat-openbsd"
fi

echo ""
echo "To connect via RDP:"
echo "  Linux: xfreerdp /v:$TAILNET_HOSTNAME:$PORT /u:mdt"
echo "  Windows: mstsc /v:$TAILNET_HOSTNAME:$PORT"
echo "  macOS: Use Microsoft Remote Desktop app"
echo ""




