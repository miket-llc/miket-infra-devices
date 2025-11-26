#!/bin/bash
# Copyright (c) 2025 MikeT LLC. All rights reserved.
#
# fix-nomachine-macos.sh - Canonical NoMachine configuration fix for macOS
#
# This script consolidates multiple fix approaches into a single, robust solution.
# It handles stuck sessions, configuration, permissions, and provides fallback options.
#
# Usage:
#   ./fix-nomachine-macos.sh              # Auto-detect and fix (requires admin)
#   sudo ./fix-nomachine-macos.sh         # Run with root privileges
#   ./fix-nomachine-macos.sh --gui        # Open GUI for manual configuration
#   ./fix-nomachine-macos.sh --diagnose   # Diagnose without making changes
#
# Target: macOS devices (count-zero, etc.)

set -euo pipefail

# Configuration
CONFIG_FILE="/Applications/NoMachine.app/Contents/Frameworks/etc/server.cfg"
NXSERVER="/Applications/NoMachine.app/Contents/Frameworks/bin/nxserver"
LAUNCHD_PLIST="/Library/LaunchDaemons/com.nomachine.nxserver.plist"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Required settings for console session sharing and UI rendering
REQUIRED_SETTINGS=(
    "EnableConsoleSessionSharing=1"
    "EnableSessionSharing=1"
    "EnableNXDisplayOutput=1"
    "EnableNewSession=1"
)

log_info()    { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[✓]${NC} $*"; }
log_warning() { echo -e "${YELLOW}[!]${NC} $*"; }
log_error()   { echo -e "${RED}[✗]${NC} $*"; }

show_help() {
    cat << 'EOF'
Usage: fix-nomachine-macos.sh [OPTIONS]

Canonical NoMachine configuration fix for macOS devices.

Options:
  --gui       Open NoMachine GUI for manual configuration
  --diagnose  Diagnose issues without making changes
  --force     Force configuration update even if settings exist
  --help, -h  Show this help message

Examples:
  sudo ./fix-nomachine-macos.sh              # Auto-fix (recommended)
  ./fix-nomachine-macos.sh --diagnose        # Check current state
  ./fix-nomachine-macos.sh --gui             # Manual GUI approach

Note: This script requires admin privileges for most operations.
EOF
}

diagnose() {
    echo "=== NoMachine Diagnostic Report ==="
    echo ""
    
    # Check installation
    if [[ -d "/Applications/NoMachine.app" ]]; then
        log_success "NoMachine is installed"
    else
        log_error "NoMachine is NOT installed"
        return 1
    fi
    
    # Check config file
    if [[ -f "$CONFIG_FILE" ]]; then
        log_success "Config file exists: $CONFIG_FILE"
    else
        log_error "Config file not found"
        return 1
    fi
    
    # Check current settings
    echo ""
    echo "=== Current Configuration ==="
    for setting in "${REQUIRED_SETTINGS[@]}"; do
        key="${setting%%=*}"
        if grep -q "^${key}=" "$CONFIG_FILE" 2>/dev/null; then
            value=$(grep "^${key}=" "$CONFIG_FILE" | head -1)
            if [[ "$value" == "$setting" ]]; then
                log_success "$value"
            else
                log_warning "$value (expected: $setting)"
            fi
        else
            log_error "$key is NOT configured"
        fi
    done
    
    # Check server status
    echo ""
    echo "=== Server Status ==="
    if "$NXSERVER" --status 2>&1 | grep -q "running"; then
        log_success "NoMachine server is running"
    else
        log_warning "NoMachine server may not be running"
    fi
    "$NXSERVER" --status 2>&1 | head -10
    
    # Check port 4000
    echo ""
    echo "=== Port Status ==="
    if lsof -i :4000 &>/dev/null; then
        log_success "Port 4000 is listening"
        lsof -i :4000 | head -3
    else
        log_error "Port 4000 is NOT listening"
    fi
    
    # Check screen recording permission
    echo ""
    echo "=== Screen Recording Permission ==="
    echo "Please verify in System Settings > Privacy & Security > Screen Recording"
    echo "that NoMachine has Screen Recording permission enabled."
}

open_gui() {
    echo "=== NoMachine GUI Configuration ==="
    echo ""
    echo "Opening NoMachine application..."
    open -a NoMachine 2>/dev/null || {
        log_error "Could not open NoMachine automatically"
        echo "Please open NoMachine manually"
    }
    echo ""
    echo "Manual configuration steps:"
    echo "1. Open NoMachine application"
    echo "2. Go to: NoMachine > Preferences > Server"
    echo "3. Enable the following settings:"
    echo "   - Enable console session sharing"
    echo "   - Enable session sharing"
    echo "   - Enable NX display output"
    echo "   - Enable new sessions"
    echo ""
    echo "4. Restart NoMachine server:"
    echo "   sudo $NXSERVER --restart"
}

cleanup_processes() {
    log_info "Cleaning up stuck NoMachine processes..."
    pkill -9 nxserver 2>/dev/null || true
    pkill -9 nxnode 2>/dev/null || true
    pkill -9 nxd 2>/dev/null || true
    sleep 2
    log_success "Process cleanup complete"
}

apply_configuration() {
    local force="${1:-false}"
    
    # Check if running as root
    if [[ "$EUID" -ne 0 ]]; then
        log_warning "Not running as root - will attempt osascript elevation"
        apply_configuration_elevated "$force"
        return $?
    fi
    
    log_info "Applying configuration with root privileges..."
    
    # Create backup
    local backup_file="${CONFIG_FILE}.backup.$(date +%Y%m%d-%H%M%S)"
    cp "$CONFIG_FILE" "$backup_file"
    log_success "Backup created: $backup_file"
    
    # Add settings
    local changes_made=false
    for setting in "${REQUIRED_SETTINGS[@]}"; do
        key="${setting%%=*}"
        if ! grep -q "^${key}=" "$CONFIG_FILE" 2>/dev/null || [[ "$force" == "true" ]]; then
            # Remove existing setting if forcing
            if [[ "$force" == "true" ]]; then
                sed -i '' "/^${key}=/d" "$CONFIG_FILE" 2>/dev/null || true
            fi
            echo "$setting" >> "$CONFIG_FILE"
            log_success "Added: $setting"
            changes_made=true
        else
            log_info "Already configured: $key"
        fi
    done
    
    if [[ "$changes_made" == "true" ]]; then
        log_success "Configuration updated"
    else
        log_info "No changes needed"
    fi
    
    return 0
}

apply_configuration_elevated() {
    local force="${1:-false}"
    
    log_info "Requesting admin privileges via osascript..."
    
    # Build the shell script to run with admin privileges
    local script_content
    script_content=$(cat << 'EOFSCRIPT'
#!/bin/bash
CONFIG_FILE="/Applications/NoMachine.app/Contents/Frameworks/etc/server.cfg"
BACKUP_FILE="${CONFIG_FILE}.backup.$(date +%Y%m%d-%H%M%S)"

# Create backup
cp "$CONFIG_FILE" "$BACKUP_FILE"

# Add settings if they don't exist
for setting in "EnableConsoleSessionSharing=1" "EnableSessionSharing=1" "EnableNXDisplayOutput=1" "EnableNewSession=1"; do
    key="${setting%%=*}"
    if ! grep -q "^${key}=" "$CONFIG_FILE" 2>/dev/null; then
        echo "$setting" >> "$CONFIG_FILE"
    fi
done

# Restart server
/Applications/NoMachine.app/Contents/Frameworks/bin/nxserver --restart 2>&1 || {
    launchctl unload /Library/LaunchDaemons/com.nomachine.nxserver.plist 2>/dev/null || true
    sleep 2
    launchctl load /Library/LaunchDaemons/com.nomachine.nxserver.plist 2>/dev/null || true
}

echo "Configuration updated successfully"
EOFSCRIPT
)
    
    # Create temp script
    local temp_script
    temp_script=$(mktemp)
    echo "$script_content" > "$temp_script"
    chmod +x "$temp_script"
    
    # Execute with admin privileges
    osascript << EOF
do shell script "bash '$temp_script'" with administrator privileges
EOF
    local result=$?
    
    # Cleanup
    rm -f "$temp_script"
    
    if [[ $result -eq 0 ]]; then
        log_success "Configuration applied via osascript"
    else
        log_error "Failed to apply configuration"
        echo ""
        echo "Manual fallback - run this command:"
        echo "  sudo $0"
    fi
    
    return $result
}

restart_server() {
    log_info "Restarting NoMachine server..."
    
    if [[ "$EUID" -eq 0 ]]; then
        "$NXSERVER" --restart 2>&1 || {
            log_warning "Restart command failed, trying launchctl..."
            launchctl unload "$LAUNCHD_PLIST" 2>/dev/null || true
            sleep 2
            launchctl load "$LAUNCHD_PLIST" 2>/dev/null || true
        }
    else
        osascript << EOF 2>/dev/null || true
do shell script "$NXSERVER --restart" with administrator privileges
EOF
    fi
    
    sleep 3
    log_success "Server restart complete"
}

verify_fix() {
    echo ""
    echo "=== Verification ==="
    
    # Check configuration
    local all_configured=true
    for setting in "${REQUIRED_SETTINGS[@]}"; do
        key="${setting%%=*}"
        if grep -q "^${setting}$" "$CONFIG_FILE" 2>/dev/null; then
            log_success "$setting"
        else
            log_error "$key not properly configured"
            all_configured=false
        fi
    done
    
    # Check server status
    if "$NXSERVER" --status 2>&1 | grep -q "running"; then
        log_success "Server is running"
    else
        log_warning "Server may not be running"
    fi
    
    # Check port
    if lsof -i :4000 &>/dev/null; then
        log_success "Port 4000 is listening"
    else
        log_error "Port 4000 is not listening"
        all_configured=false
    fi
    
    if [[ "$all_configured" == "true" ]]; then
        echo ""
        log_success "NoMachine configuration fix complete!"
        echo ""
        echo "Next steps:"
        echo "1. Verify Screen Recording permission in System Settings"
        echo "2. Test connection from remote client"
        echo "3. Try both 'Console Session' and 'New Session' options"
    else
        echo ""
        log_warning "Some issues remain - check the errors above"
    fi
}

main() {
    local mode="fix"
    local force=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --gui)
                mode="gui"
                shift
                ;;
            --diagnose)
                mode="diagnose"
                shift
                ;;
            --force)
                force=true
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    echo "=== NoMachine macOS Configuration Fix ==="
    echo "Target: $(hostname)"
    echo "Date: $(date)"
    echo ""
    
    case "$mode" in
        gui)
            open_gui
            ;;
        diagnose)
            diagnose
            ;;
        fix)
            cleanup_processes
            apply_configuration "$force"
            restart_server
            verify_fix
            ;;
    esac
}

main "$@"

