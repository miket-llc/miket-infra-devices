#!/bin/bash
# Copyright (c) 2025 MikeT LLC. All rights reserved.
#
# monitor-nextcloud-permissions.sh
# Scans Nextcloud sync directories and auto-corrects permission issues.
#
# Runbook: docs/runbooks/nextcloud-permissions-troubleshooting.md
#
# This script is designed to run periodically via LaunchAgent (macOS).
# It scans configured sync roots for directories with overly restrictive
# permissions and delegates fixes to fix-nextcloud-folder-permissions.sh.
#
# Usage:
#   monitor-nextcloud-permissions.sh [<comma-separated-roots>]
#   monitor-nextcloud-permissions.sh /Users/miket/cloud
#   monitor-nextcloud-permissions.sh "/Users/miket/cloud,/Users/miket/nc"
#
# Environment:
#   NEXTCLOUD_SYNC_ROOTS  - Comma-separated list of sync roots (fallback if no args)
#
# Configuration:
#   The script can be configured via:
#   1. Command-line arguments (preferred)
#   2. NEXTCLOUD_SYNC_ROOTS environment variable
#   3. Default to ~/cloud if nothing else specified
#
# IMPORTANT: This operates on LOCAL sync directories only.
# It must NEVER be used on /space (SoR) on motoko.

set -uo pipefail

# =============================================================================
# Configuration
# =============================================================================
SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_PREFIX="[nextcloud-perms-monitor]"

# Path to the fix script (check multiple locations)
FIX_SCRIPT=""
for candidate in \
    "${SCRIPT_DIR}/fix-nextcloud-folder-permissions.sh" \
    "/usr/local/miket/bin/fix-nextcloud-folder-permissions.sh" \
    "${HOME}/.scripts/fix-nextcloud-folder-permissions.sh"; do
    if [[ -x "$candidate" ]]; then
        FIX_SCRIPT="$candidate"
        break
    fi
done

# Default sync root
DEFAULT_SYNC_ROOT="${HOME}/cloud"

# Log file (set by LaunchAgent typically)
LOG_FILE="${NEXTCLOUD_PERMS_LOG_FILE:-${HOME}/Library/Logs/nextcloud-permissions-monitor.log}"

# =============================================================================
# Functions
# =============================================================================
log_msg() {
    local level="$1"
    shift
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    echo "${timestamp} ${LOG_PREFIX} ${level}: $*"
}

log_info() {
    log_msg "INFO" "$@"
}

log_warn() {
    log_msg "WARN" "$@" >&2
}

log_error() {
    log_msg "ERROR" "$@" >&2
}

usage() {
    cat <<EOF
Usage: $SCRIPT_NAME [<comma-separated-roots>]

Monitor and auto-fix Nextcloud sync directory permissions.

Arguments:
    <roots>         Comma-separated list of sync root paths
                    If not provided, uses NEXTCLOUD_SYNC_ROOTS env var
                    Falls back to ~/cloud if neither specified

Environment Variables:
    NEXTCLOUD_SYNC_ROOTS    Comma-separated list of sync roots
    NEXTCLOUD_PERMS_LOG_FILE   Log file path (default: ~/Library/Logs/nextcloud-permissions-monitor.log)

Examples:
    $SCRIPT_NAME
    $SCRIPT_NAME /Users/miket/cloud
    $SCRIPT_NAME "/Users/miket/cloud,/Users/miket/nc"
    NEXTCLOUD_SYNC_ROOTS="/Users/miket/cloud" $SCRIPT_NAME

Exit Codes:
    0   Success (no issues or all issues fixed)
    1   Unexpected error (fix script failed or missing)
    2   Configuration error (no valid roots)

EOF
    exit 0
}

# Count directories with overly restrictive permissions
count_restrictive_dirs() {
    local root="$1"
    find "$root" -type d -perm 700 2>/dev/null | wc -l | tr -d ' '
}

# Count files with overly restrictive permissions
count_restrictive_files() {
    local root="$1"
    find "$root" -type f -perm 600 2>/dev/null | wc -l | tr -d ' '
}

# Parse comma-separated roots into array
parse_roots() {
    local input="$1"
    local -a roots=()
    
    IFS=',' read -ra parts <<< "$input"
    for part in "${parts[@]}"; do
        # Trim whitespace and expand ~
        part="${part## }"
        part="${part%% }"
        part="${part/#\~/$HOME}"
        
        if [[ -n "$part" ]]; then
            roots+=("$part")
        fi
    done
    
    printf '%s\n' "${roots[@]}"
}

# =============================================================================
# Main
# =============================================================================
main() {
    local roots_input=""
    local -a sync_roots=()
    local has_errors=0
    local total_fixes=0
    
    # Parse arguments
    if [[ $# -gt 0 ]]; then
        case "$1" in
            --help|-h)
                usage
                ;;
            *)
                roots_input="$1"
                ;;
        esac
    fi
    
    # Determine sync roots (args > env > default)
    if [[ -n "$roots_input" ]]; then
        while IFS= read -r root; do
            sync_roots+=("$root")
        done < <(parse_roots "$roots_input")
    elif [[ -n "${NEXTCLOUD_SYNC_ROOTS:-}" ]]; then
        while IFS= read -r root; do
            sync_roots+=("$root")
        done < <(parse_roots "$NEXTCLOUD_SYNC_ROOTS")
    else
        sync_roots+=("$DEFAULT_SYNC_ROOT")
    fi
    
    # Validate we have roots to check
    if [[ ${#sync_roots[@]} -eq 0 ]]; then
        log_error "No sync roots configured"
        exit 2
    fi
    
    # Validate fix script exists
    if [[ -z "$FIX_SCRIPT" ]]; then
        log_error "Fix script not found. Expected at:"
        log_error "  - ${SCRIPT_DIR}/fix-nextcloud-folder-permissions.sh"
        log_error "  - /usr/local/miket/bin/fix-nextcloud-folder-permissions.sh"
        log_error "  - ${HOME}/.scripts/fix-nextcloud-folder-permissions.sh"
        exit 1
    fi
    
    log_info "Starting Nextcloud permissions monitor"
    log_info "Fix script: $FIX_SCRIPT"
    log_info "Sync roots: ${sync_roots[*]}"
    
    # Process each sync root
    for root in "${sync_roots[@]}"; do
        log_info "Scanning: $root"
        
        # Skip if root doesn't exist
        if [[ ! -d "$root" ]]; then
            log_warn "Sync root does not exist, skipping: $root"
            continue
        fi
        
        # Count issues before fix
        local dirs_before files_before
        dirs_before=$(count_restrictive_dirs "$root")
        files_before=$(count_restrictive_files "$root")
        
        if [[ "$dirs_before" -eq 0 && "$files_before" -eq 0 ]]; then
            log_info "No permission issues in: $root"
            continue
        fi
        
        log_info "Found issues in $root: $dirs_before dirs (700), $files_before files (600)"
        
        # Run the fix script
        if "$FIX_SCRIPT" "$root" 2>&1; then
            # Count issues after fix
            local dirs_after files_after
            dirs_after=$(count_restrictive_dirs "$root")
            files_after=$(count_restrictive_files "$root")
            
            local fixed_dirs=$((dirs_before - dirs_after))
            local fixed_files=$((files_before - files_after))
            total_fixes=$((total_fixes + fixed_dirs + fixed_files))
            
            log_info "Fixed in $root: $fixed_dirs dirs, $fixed_files files"
            
            if [[ "$dirs_after" -gt 0 || "$files_after" -gt 0 ]]; then
                log_warn "Remaining issues in $root: $dirs_after dirs, $files_after files"
            fi
        else
            log_error "Fix script failed for: $root"
            has_errors=1
        fi
    done
    
    log_info "Monitor complete. Total fixes: $total_fixes"
    
    exit $has_errors
}

main "$@"

