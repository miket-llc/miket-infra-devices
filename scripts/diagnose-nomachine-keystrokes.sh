#!/bin/bash
#
# NoMachine Keystroke Dropping Diagnostic Script
# 
# Purpose: Gather diagnostic information for keystroke dropping issues
# Usage: Run on motoko (server) during active NoMachine session
#
# Author: Codex-CA-001 (Chief Architect)
# Date: 2025-11-24

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="${SCRIPT_DIR}/../artifacts"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT_FILE="${OUTPUT_DIR}/nomachine-keystroke-diagnostic-${TIMESTAMP}.txt"

mkdir -p "${OUTPUT_DIR}"

echo "=========================================" | tee -a "${REPORT_FILE}"
echo "NoMachine Keystroke Diagnostic Report" | tee -a "${REPORT_FILE}"
echo "Generated: $(date)" | tee -a "${REPORT_FILE}"
echo "=========================================" | tee -a "${REPORT_FILE}"
echo "" | tee -a "${REPORT_FILE}"

# 1. System Information
echo "=== SYSTEM INFORMATION ===" | tee -a "${REPORT_FILE}"
echo "Hostname: $(hostname)" | tee -a "${REPORT_FILE}"
echo "OS: $(lsb_release -d 2>/dev/null | cut -f2 || uname -a)" | tee -a "${REPORT_FILE}"
echo "Kernel: $(uname -r)" | tee -a "${REPORT_FILE}"
echo "" | tee -a "${REPORT_FILE}"

# 2. NoMachine Server Status
echo "=== NOMACHINE SERVER STATUS ===" | tee -a "${REPORT_FILE}"
if systemctl is-active --quiet nxserver; then
    echo "Service: ACTIVE" | tee -a "${REPORT_FILE}"
    systemctl status nxserver --no-pager | tee -a "${REPORT_FILE}"
else
    echo "Service: INACTIVE" | tee -a "${REPORT_FILE}"
fi
echo "" | tee -a "${REPORT_FILE}"

# 3. NoMachine Version
echo "=== NOMACHINE VERSION ===" | tee -a "${REPORT_FILE}"
if [ -f /usr/NX/bin/nxserver ]; then
    /usr/NX/bin/nxserver --version 2>&1 | tee -a "${REPORT_FILE}"
else
    echo "NoMachine server not found" | tee -a "${REPORT_FILE}"
fi
echo "" | tee -a "${REPORT_FILE}"

# 4. Active Sessions
echo "=== ACTIVE NOMACHINE SESSIONS ===" | tee -a "${REPORT_FILE}"
if [ -f /usr/NX/bin/nxserver ]; then
    /usr/NX/bin/nxserver --status 2>&1 | tee -a "${REPORT_FILE}"
else
    echo "Cannot check sessions - nxserver not found" | tee -a "${REPORT_FILE}"
fi
echo "" | tee -a "${REPORT_FILE}"

# 5. Network Connectivity to count-zero
echo "=== NETWORK CONNECTIVITY ===" | tee -a "${REPORT_FILE}"
echo "Testing connectivity to count-zero..." | tee -a "${REPORT_FILE}"
if ping -c 5 count-zero.pangolin-vega.ts.net > /tmp/ping-test.txt 2>&1; then
    cat /tmp/ping-test.txt | tee -a "${REPORT_FILE}"
    PACKET_LOSS=$(grep "packet loss" /tmp/ping-test.txt | grep -oP '\d+(?=%)' || echo "0")
    echo "Packet Loss: ${PACKET_LOSS}%" | tee -a "${REPORT_FILE}"
else
    echo "Ping test failed" | tee -a "${REPORT_FILE}"
    cat /tmp/ping-test.txt | tee -a "${REPORT_FILE}"
fi
rm -f /tmp/ping-test.txt
echo "" | tee -a "${REPORT_FILE}"

# 6. Tailscale Status
echo "=== TAILSCALE STATUS ===" | tee -a "${REPORT_FILE}"
if command -v tailscale >/dev/null 2>&1; then
    tailscale status | grep -E "(count-zero|motoko)" | tee -a "${REPORT_FILE}"
    echo "" | tee -a "${REPORT_FILE}"
    echo "Connection type:" | tee -a "${REPORT_FILE}"
    tailscale status | grep count-zero | grep -oE "(direct|relay)" | tee -a "${REPORT_FILE}" || echo "Unknown" | tee -a "${REPORT_FILE}"
else
    echo "Tailscale not found" | tee -a "${REPORT_FILE}"
fi
echo "" | tee -a "${REPORT_FILE}"

# 7. System Resources
echo "=== SYSTEM RESOURCES ===" | tee -a "${REPORT_FILE}"
echo "CPU Load:" | tee -a "${REPORT_FILE}"
uptime | tee -a "${REPORT_FILE}"
echo "" | tee -a "${REPORT_FILE}"
echo "Memory Usage:" | tee -a "${REPORT_FILE}"
free -h | tee -a "${REPORT_FILE}"
echo "" | tee -a "${REPORT_FILE}"
echo "NoMachine Process Resources:" | tee -a "${REPORT_FILE}"
ps aux | grep -E "(nxserver|nxd|nxnode)" | grep -v grep | tee -a "${REPORT_FILE}" || echo "No NoMachine processes found" | tee -a "${REPORT_FILE}"
echo "" | tee -a "${REPORT_FILE}"

# 8. NoMachine Server Configuration
echo "=== NOMACHINE SERVER CONFIGURATION ===" | tee -a "${REPORT_FILE}"
if [ -f /usr/NX/etc/server.cfg ]; then
    echo "Configuration file exists" | tee -a "${REPORT_FILE}"
    echo "Key settings:" | tee -a "${REPORT_FILE}"
    sudo grep -E "^[^#].*=" /usr/NX/etc/server.cfg | head -20 | tee -a "${REPORT_FILE}"
else
    echo "Configuration file not found" | tee -a "${REPORT_FILE}"
fi
echo "" | tee -a "${REPORT_FILE}"

# 9. Recent NoMachine Logs
echo "=== RECENT NOMACHINE LOGS (Last 50 lines) ===" | tee -a "${REPORT_FILE}"
if systemctl is-active --quiet nxserver; then
    sudo journalctl -u nxserver --since "1 hour ago" --no-pager | tail -50 | tee -a "${REPORT_FILE}"
else
    echo "NoMachine service not running - cannot retrieve logs" | tee -a "${REPORT_FILE}"
fi
echo "" | tee -a "${REPORT_FILE}"

# 10. X11 Input Configuration
echo "=== X11 INPUT CONFIGURATION ===" | tee -a "${REPORT_FILE}"
if command -v xset >/dev/null 2>&1 && [ -n "${DISPLAY:-}" ]; then
    xset q 2>&1 | tee -a "${REPORT_FILE}"
else
    echo "X11 not available or DISPLAY not set" | tee -a "${REPORT_FILE}"
fi
echo "" | tee -a "${REPORT_FILE}"

# 11. Keyboard Layout
echo "=== KEYBOARD LAYOUT ===" | tee -a "${REPORT_FILE}"
if command -v setxkbmap >/dev/null 2>&1 && [ -n "${DISPLAY:-}" ]; then
    setxkbmap -print 2>&1 | tee -a "${REPORT_FILE}"
else
    echo "setxkbmap not available or DISPLAY not set" | tee -a "${REPORT_FILE}"
fi
echo "" | tee -a "${REPORT_FILE}"

# 12. Input Method Status
echo "=== INPUT METHOD STATUS ===" | tee -a "${REPORT_FILE}"
if command -v ibus >/dev/null 2>&1; then
    ibus list-engine 2>&1 | tee -a "${REPORT_FILE}" || echo "ibus not running" | tee -a "${REPORT_FILE}"
else
    echo "ibus not installed" | tee -a "${REPORT_FILE}"
fi
echo "" | tee -a "${REPORT_FILE}"

# 13. Network Interface Statistics
echo "=== NETWORK INTERFACE STATISTICS ===" | tee -a "${REPORT_FILE}"
if ip link show tailscale0 >/dev/null 2>&1; then
    echo "Tailscale interface (tailscale0):" | tee -a "${REPORT_FILE}"
    ip -s link show tailscale0 | tee -a "${REPORT_FILE}"
else
    echo "Tailscale interface not found" | tee -a "${REPORT_FILE}"
fi
echo "" | tee -a "${REPORT_FILE}"

# Summary
echo "=========================================" | tee -a "${REPORT_FILE}"
echo "DIAGNOSTIC COMPLETE" | tee -a "${REPORT_FILE}"
echo "Report saved to: ${REPORT_FILE}" | tee -a "${REPORT_FILE}"
echo "=========================================" | tee -a "${REPORT_FILE}"

echo ""
echo "Diagnostic report generated: ${REPORT_FILE}"
echo "Review the report and share with the team for analysis."

