#!/bin/bash
# Copyright (c) 2025 MikeT LLC. All rights reserved.

#
# NoMachine macOS UI Rendering Diagnostic Script
# 
# Purpose: Gather diagnostic information for UI rendering issues when connecting
#          to macOS (count-zero) via NoMachine from Windows clients
# Usage: Run on count-zero (macOS) via SSH from wintermute or armitage
#
# Author: Codex-CA-001 (Chief Architect) & Codex-MAC-012 (macOS Engineer)
# Date: 2025-11-27

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="${SCRIPT_DIR}/../artifacts"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT_FILE="${OUTPUT_DIR}/nomachine-macos-ui-diagnostic-${TIMESTAMP}.txt"

mkdir -p "${OUTPUT_DIR}"

echo "=========================================" | tee -a "${REPORT_FILE}"
echo "NoMachine macOS UI Rendering Diagnostic Report" | tee -a "${REPORT_FILE}"
echo "Generated: $(date)" | tee -a "${REPORT_FILE}"
echo "Host: $(hostname)" | tee -a "${REPORT_FILE}"
echo "=========================================" | tee -a "${REPORT_FILE}"
echo "" | tee -a "${REPORT_FILE}"

# 1. System Information
echo "=== SYSTEM INFORMATION ===" | tee -a "${REPORT_FILE}"
echo "Hostname: $(hostname)" | tee -a "${REPORT_FILE}"
echo "OS: $(sw_vers -productName) $(sw_vers -productVersion)" | tee -a "${REPORT_FILE}"
echo "Build: $(sw_vers -buildVersion)" | tee -a "${REPORT_FILE}"
echo "Kernel: $(uname -r)" | tee -a "${REPORT_FILE}"
echo "Architecture: $(uname -m)" | tee -a "${REPORT_FILE}"
echo "" | tee -a "${REPORT_FILE}"

# 2. Active User Sessions
echo "=== ACTIVE USER SESSIONS ===" | tee -a "${REPORT_FILE}"
who | tee -a "${REPORT_FILE}"
echo "" | tee -a "${REPORT_FILE}"
echo "Console user:" | tee -a "${REPORT_FILE}"
stat -f "%Su" /dev/console 2>/dev/null | tee -a "${REPORT_FILE}" || echo "Unable to determine" | tee -a "${REPORT_FILE}"
echo "" | tee -a "${REPORT_FILE}"

# 3. NoMachine Server Status
echo "=== NOMACHINE SERVER STATUS ===" | tee -a "${REPORT_FILE}"
if [ -f /usr/NX/bin/nxserver ]; then
    echo "Server executable found" | tee -a "${REPORT_FILE}"
    sudo /usr/NX/bin/nxserver --status 2>&1 | tee -a "${REPORT_FILE}"
    echo "" | tee -a "${REPORT_FILE}"
    echo "Server version:" | tee -a "${REPORT_FILE}"
    /usr/NX/bin/nxserver --version 2>&1 | tee -a "${REPORT_FILE}"
else
    echo "NoMachine server not found at /usr/NX/bin/nxserver" | tee -a "${REPORT_FILE}"
    echo "Checking alternative locations..." | tee -a "${REPORT_FILE}"
    find /Applications -name "nxserver" -type f 2>/dev/null | tee -a "${REPORT_FILE}" || echo "No nxserver found" | tee -a "${REPORT_FILE}"
fi
echo "" | tee -a "${REPORT_FILE}"

# 4. NoMachine Processes
echo "=== NOMACHINE PROCESSES ===" | tee -a "${REPORT_FILE}"
ps aux | grep -i -E "(nomachine|nxserver|nxd|nxnode)" | grep -v grep | tee -a "${REPORT_FILE}" || echo "No NoMachine processes found" | tee -a "${REPORT_FILE}"
echo "" | tee -a "${REPORT_FILE}"

# 5. Port Listening Status
echo "=== PORT 4000 LISTENING STATUS ===" | tee -a "${REPORT_FILE}"
if command -v lsof >/dev/null 2>&1; then
    sudo lsof -i :4000 2>&1 | tee -a "${REPORT_FILE}" || echo "Port 4000 not listening or lsof failed" | tee -a "${REPORT_FILE}"
else
    echo "lsof not available" | tee -a "${REPORT_FILE}"
    netstat -an | grep 4000 | tee -a "${REPORT_FILE}" || echo "netstat not available or port not found" | tee -a "${REPORT_FILE}"
fi
echo "" | tee -a "${REPORT_FILE}"

# 6. NoMachine Server Configuration
echo "=== NOMACHINE SERVER CONFIGURATION ===" | tee -a "${REPORT_FILE}"
CONFIG_PATHS=(
    "/Applications/NoMachine.app/Contents/Frameworks/etc/server.cfg"
    "/usr/NX/etc/server.cfg"
    "/etc/nxserver/server.cfg"
)

CONFIG_FOUND=false
for CONFIG_PATH in "${CONFIG_PATHS[@]}"; do
    if [ -f "$CONFIG_PATH" ]; then
        echo "Configuration file: $CONFIG_PATH" | tee -a "${REPORT_FILE}"
        echo "Key settings:" | tee -a "${REPORT_FILE}"
        sudo grep -i -E "(console|session|display|EnableNXDisplayOutput|EnableSessionSharing|EnableConsoleSessionSharing)" "$CONFIG_PATH" 2>/dev/null | tee -a "${REPORT_FILE}" || echo "No relevant settings found" | tee -a "${REPORT_FILE}"
        CONFIG_FOUND=true
        break
    fi
done

if [ "$CONFIG_FOUND" = false ]; then
    echo "NoMachine server configuration file not found in standard locations" | tee -a "${REPORT_FILE}"
fi
echo "" | tee -a "${REPORT_FILE}"

# 7. macOS Screen Recording Permissions
echo "=== SCREEN RECORDING PERMISSIONS ===" | tee -a "${REPORT_FILE}"
if [ -f ~/Library/Application\ Support/com.apple.TCC/TCC.db ]; then
    echo "Checking TCC database for Screen Recording permissions..." | tee -a "${REPORT_FILE}"
    sqlite3 ~/Library/Application\ Support/com.apple.TCC/TCC.db "SELECT service, client, allowed, auth_value FROM access WHERE service='kTCCServiceScreenRecording' AND (client LIKE '%nomachine%' OR client LIKE '%nxserver%' OR client LIKE '%NoMachine%');" 2>&1 | tee -a "${REPORT_FILE}" || echo "Unable to query TCC database" | tee -a "${REPORT_FILE}"
    
    echo "" | tee -a "${REPORT_FILE}"
    echo "All Screen Recording permissions:" | tee -a "${REPORT_FILE}"
    sqlite3 ~/Library/Application\ Support/com.apple.TCC/TCC.db "SELECT service, client, allowed FROM access WHERE service='kTCCServiceScreenRecording';" 2>&1 | tee -a "${REPORT_FILE}" || echo "Unable to query TCC database" | tee -a "${REPORT_FILE}"
else
    echo "TCC database not found (may require user login)" | tee -a "${REPORT_FILE}"
fi
echo "" | tee -a "${REPORT_FILE}"

# 8. macOS Accessibility Permissions
echo "=== ACCESSIBILITY PERMISSIONS ===" | tee -a "${REPORT_FILE}"
if [ -f ~/Library/Application\ Support/com.apple.TCC/TCC.db ]; then
    echo "Checking TCC database for Accessibility permissions..." | tee -a "${REPORT_FILE}"
    sqlite3 ~/Library/Application\ Support/com.apple.TCC/TCC.db "SELECT service, client, allowed FROM access WHERE service='kTCCServiceAccessibility' AND (client LIKE '%nomachine%' OR client LIKE '%nxserver%' OR client LIKE '%NoMachine%');" 2>&1 | tee -a "${REPORT_FILE}" || echo "Unable to query TCC database" | tee -a "${REPORT_FILE}"
else
    echo "TCC database not found (may require user login)" | tee -a "${REPORT_FILE}"
fi
echo "" | tee -a "${REPORT_FILE}"

# 9. Display Information
echo "=== DISPLAY INFORMATION ===" | tee -a "${REPORT_FILE}"
echo "DISPLAY environment variable: ${DISPLAY:-not set}" | tee -a "${REPORT_FILE}"
echo "" | tee -a "${REPORT_FILE}"
echo "Active displays:" | tee -a "${REPORT_FILE}"
system_profiler SPDisplaysDataType 2>/dev/null | grep -i -E "(resolution|display|connected)" | head -20 | tee -a "${REPORT_FILE}" || echo "Unable to get display information" | tee -a "${REPORT_FILE}"
echo "" | tee -a "${REPORT_FILE}"

# 10. WindowServer Status
echo "=== WINDOWSERVER STATUS ===" | tee -a "${REPORT_FILE}"
if ps aux | grep -i WindowServer | grep -v grep >/dev/null 2>&1; then
    echo "WindowServer is running" | tee -a "${REPORT_FILE}"
    ps aux | grep -i WindowServer | grep -v grep | tee -a "${REPORT_FILE}"
else
    echo "WindowServer is NOT running (this may cause display issues)" | tee -a "${REPORT_FILE}"
fi
echo "" | tee -a "${REPORT_FILE}"

# 11. Display Sleep Settings
echo "=== DISPLAY SLEEP SETTINGS ===" | tee -a "${REPORT_FILE}"
pmset -g 2>/dev/null | grep -i display | tee -a "${REPORT_FILE}" || echo "Unable to get power management settings" | tee -a "${REPORT_FILE}"
echo "" | tee -a "${REPORT_FILE}"

# 12. NoMachine Server Logs
echo "=== RECENT NOMACHINE SERVER LOGS (Last 50 lines) ===" | tee -a "${REPORT_FILE}"
LOG_PATHS=(
    "/usr/NX/var/log/nxserver.log"
    "/Applications/NoMachine.app/Contents/Frameworks/var/log/nxserver.log"
    "/var/log/nxserver.log"
)

LOG_FOUND=false
for LOG_PATH in "${LOG_PATHS[@]}"; do
    if [ -f "$LOG_PATH" ]; then
        echo "Log file: $LOG_PATH" | tee -a "${REPORT_FILE}"
        sudo tail -50 "$LOG_PATH" 2>&1 | tee -a "${REPORT_FILE}"
        LOG_FOUND=true
        break
    fi
done

if [ "$LOG_FOUND" = false ]; then
    echo "NoMachine server log file not found in standard locations" | tee -a "${REPORT_FILE}"
    echo "Searching for log files..." | tee -a "${REPORT_FILE}"
    find /usr/NX /Applications/NoMachine.app -name "*.log" -type f 2>/dev/null | head -5 | tee -a "${REPORT_FILE}" || echo "No log files found" | tee -a "${REPORT_FILE}"
fi
echo "" | tee -a "${REPORT_FILE}"

# 13. Tailscale Connectivity
echo "=== TAILSCALE STATUS ===" | tee -a "${REPORT_FILE}"
if command -v tailscale >/dev/null 2>&1; then
    echo "Tailscale status:" | tee -a "${REPORT_FILE}"
    tailscale status 2>&1 | grep -E "(armitage|wintermute|count-zero)" | tee -a "${REPORT_FILE}" || echo "No relevant devices found" | tee -a "${REPORT_FILE}"
    echo "" | tee -a "${REPORT_FILE}"
    echo "Tailscale IP:" | tee -a "${REPORT_FILE}"
    tailscale ip -4 2>&1 | tee -a "${REPORT_FILE}" || echo "Unable to get Tailscale IP" | tee -a "${REPORT_FILE}"
else
    echo "Tailscale not found" | tee -a "${REPORT_FILE}"
fi
echo "" | tee -a "${REPORT_FILE}"

# 14. Network Connectivity Test
echo "=== NETWORK CONNECTIVITY TEST ===" | tee -a "${REPORT_FILE}"
echo "Testing connectivity to armitage..." | tee -a "${REPORT_FILE}"
ping -c 3 armitage.pangolin-vega.ts.net 2>&1 | tee -a "${REPORT_FILE}" || echo "Ping failed" | tee -a "${REPORT_FILE}"
echo "" | tee -a "${REPORT_FILE}"
echo "Testing connectivity to wintermute..." | tee -a "${REPORT_FILE}"
ping -c 3 wintermute.pangolin-vega.ts.net 2>&1 | tee -a "${REPORT_FILE}" || echo "Ping failed" | tee -a "${REPORT_FILE}"
echo "" | tee -a "${REPORT_FILE}"

# 15. System Resources
echo "=== SYSTEM RESOURCES ===" | tee -a "${REPORT_FILE}"
echo "CPU Load:" | tee -a "${REPORT_FILE}"
uptime | tee -a "${REPORT_FILE}"
echo "" | tee -a "${REPORT_FILE}"
echo "Memory Usage:" | tee -a "${REPORT_FILE}"
vm_stat | head -10 | tee -a "${REPORT_FILE}" || echo "Unable to get memory stats" | tee -a "${REPORT_FILE}"
echo "" | tee -a "${REPORT_FILE}"

# Summary and Recommendations
echo "=========================================" | tee -a "${REPORT_FILE}"
echo "DIAGNOSTIC SUMMARY" | tee -a "${REPORT_FILE}"
echo "=========================================" | tee -a "${REPORT_FILE}"
echo "" | tee -a "${REPORT_FILE}"

# Check critical items
ISSUES=0

if ! ps aux | grep -i nxserver | grep -v grep >/dev/null 2>&1; then
    echo "❌ ISSUE: NoMachine server process not running" | tee -a "${REPORT_FILE}"
    ISSUES=$((ISSUES + 1))
fi

if ! sudo lsof -i :4000 2>/dev/null | grep LISTEN >/dev/null 2>&1; then
    echo "❌ ISSUE: Port 4000 not listening" | tee -a "${REPORT_FILE}"
    ISSUES=$((ISSUES + 1))
fi

if [ -f ~/Library/Application\ Support/com.apple.TCC/TCC.db ]; then
    SCREEN_REC=$(sqlite3 ~/Library/Application\ Support/com.apple.TCC/TCC.db "SELECT allowed FROM access WHERE service='kTCCServiceScreenRecording' AND (client LIKE '%nomachine%' OR client LIKE '%nxserver%') LIMIT 1;" 2>/dev/null || echo "0")
    if [ "$SCREEN_REC" != "1" ]; then
        echo "⚠️  WARNING: Screen Recording permission may not be granted to NoMachine" | tee -a "${REPORT_FILE}"
        ISSUES=$((ISSUES + 1))
    fi
fi

if ! ps aux | grep -i WindowServer | grep -v grep >/dev/null 2>&1; then
    echo "❌ ISSUE: WindowServer not running (display server required)" | tee -a "${REPORT_FILE}"
    ISSUES=$((ISSUES + 1))
fi

if [ $ISSUES -eq 0 ]; then
    echo "✅ No critical issues detected" | tee -a "${REPORT_FILE}"
    echo "   Review detailed diagnostics above for configuration recommendations" | tee -a "${REPORT_FILE}"
else
    echo "" | tee -a "${REPORT_FILE}"
    echo "⚠️  Found $ISSUES potential issue(s) - review recommendations above" | tee -a "${REPORT_FILE}"
fi

echo "" | tee -a "${REPORT_FILE}"
echo "=========================================" | tee -a "${REPORT_FILE}"
echo "DIAGNOSTIC COMPLETE" | tee -a "${REPORT_FILE}"
echo "Report saved to: ${REPORT_FILE}" | tee -a "${REPORT_FILE}"
echo "=========================================" | tee -a "${REPORT_FILE}"

echo ""
echo "Diagnostic report generated: ${REPORT_FILE}"
echo "Review the report and follow the troubleshooting guide:"
echo "  docs/guides/nomachine-macos-ui-rendering-troubleshooting.md"


