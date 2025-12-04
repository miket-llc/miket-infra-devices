#!/bin/bash
# Copyright (c) 2025 MikeT LLC. All rights reserved.
#
# fix-nextcloud-folder-permissions.sh
# Normalizes permissions in Nextcloud sync directories on macOS clients.
#
# Runbook: docs/runbooks/nextcloud-permissions-troubleshooting.md
#
# Root cause: Obsidian/macOS may create vault subfolders with overly
# restrictive permissions (700), causing Nextcloud client sync errors
# (red icon on affected folders).
#
# This script corrects:
#   - Directories: 700 (drwx------) → 755 (drwxr-xr-x)
#   - Files: 600 (-rw-------) → 644 (-rw-r--r--)
#
# Usage: fix-nextcloud-folder-permissions.sh [--dry-run] <path> [<path>...]
#
# IMPORTANT: This operates on LOCAL sync directories only.
# It must NEVER be used on /space (SoR) on motoko.

set -euo pipefail

# =============================================================================
# Configuration
# =============================================================================
SCRIPT_NAME="$(basename "$0")"
LOG_PREFIX="[nextcloud-perms-fix]"

# Safety: refuse to operate on these paths
FORBIDDEN_ROOTS=(
    "/"
    "/Users"
    "/var"
    "/etc"
    "/System"
    "/Library"
    "/private"
    "/space"           # Motoko SoR - NEVER touch
    "/flux"            # Motoko apps - NEVER touch
    "/Volumes"
)

# =============================================================================
# Functions
# =============================================================================
log_info() {
    echo "${LOG_PREFIX} INFO: $*"
}

log_warn() {
    echo "${LOG_PREFIX} WARN: $*" >&2
}

log_error() {
    echo "${LOG_PREFIX} ERROR: $*" >&2
}

usage() {
    cat <<EOF
Usage: $SCRIPT_NAME [OPTIONS] <path> [<path>...]

Normalizes permissions in Nextcloud sync directories.

Options:
    --dry-run       Show what would be changed without making changes
    --user USER     Ensure ownership matches USER (default: current user)
    --help          Show this help message

Arguments:
    <path>          One or more root paths to normalize (required)

Examples:
    $SCRIPT_NAME ~/cloud
    $SCRIPT_NAME --dry-run ~/cloud/work ~/cloud/inbox
    $SCRIPT_NAME --user miket ~/cloud

Safety:
    - Refuses to operate on system directories (/, /Users, /space, etc.)
    - Only fixes overly restrictive permissions (700 dirs, 600 files)
    - Idempotent: safe to run multiple times

EOF
    exit 0
}

is_forbidden_root() {
    local path="$1"
    local resolved_path
    
    # Resolve to absolute path
    resolved_path="$(cd "$path" 2>/dev/null && pwd)" || resolved_path="$path"
    
    for forbidden in "${FORBIDDEN_ROOTS[@]}"; do
        if [[ "$resolved_path" == "$forbidden" || "$resolved_path" == "$forbidden"/* && "$(dirname "$resolved_path")" == "$forbidden" ]]; then
            # Direct match or immediate child of forbidden root (but allow deeper paths)
            if [[ "$resolved_path" == "$forbidden" ]]; then
                return 0
            fi
            # Check if it's an immediate child (e.g., /Users/miket is OK, /Users is not)
            local parent_of_resolved
            parent_of_resolved="$(dirname "$resolved_path")"
            if [[ "$parent_of_resolved" == "/" || "$parent_of_resolved" == "/Users" ]]; then
                # /Users/miket is OK, / or /Users is not
                if [[ "$resolved_path" == "/Users" || "$resolved_path" == "/" ]]; then
                    return 0
                fi
            fi
        fi
    done
    
    # Additional check: don't allow /space or /flux anywhere
    if [[ "$resolved_path" == /space* || "$resolved_path" == /flux* ]]; then
        return 0  # Forbidden
    fi
    
    return 1  # Allowed
}

validate_path() {
    local path="$1"
    
    if [[ ! -d "$path" ]]; then
        log_error "Path does not exist or is not a directory: $path"
        return 1
    fi
    
    if is_forbidden_root "$path"; then
        log_error "Refusing to operate on forbidden/system path: $path"
        return 1
    fi
    
    return 0
}

fix_permissions() {
    local root="$1"
    local target_user="$2"
    local dry_run="$3"
    
    local dir_count=0
    local file_count=0
    local chown_count=0
    
    log_info "Processing: $root (user: $target_user, dry_run: $dry_run)"
    
    # Fix directories with 700 permissions (overly restrictive - no group/other access)
    while IFS= read -r -d '' dir; do
        if [[ "$dry_run" == "true" ]]; then
            log_info "[DRY-RUN] Would chmod 755: $dir"
        else
            chmod 755 "$dir"
            log_info "Fixed dir permissions (755): $dir"
        fi
        ((dir_count++))
    done < <(find "$root" -type d -perm 700 -print0 2>/dev/null)
    
    # Fix files with 600 permissions (overly restrictive - no group/other read)
    while IFS= read -r -d '' file; do
        if [[ "$dry_run" == "true" ]]; then
            log_info "[DRY-RUN] Would chmod 644: $file"
        else
            chmod 644 "$file"
            log_info "Fixed file permissions (644): $file"
        fi
        ((file_count++))
    done < <(find "$root" -type f -perm 600 -print0 2>/dev/null)
    
    # Fix ownership if needed (only if current owner doesn't match target user)
    if [[ -n "$target_user" ]]; then
        local target_uid
        target_uid="$(id -u "$target_user" 2>/dev/null)" || {
            log_warn "Could not resolve user ID for: $target_user"
            target_uid=""
        }
        
        if [[ -n "$target_uid" ]]; then
            while IFS= read -r -d '' item; do
                local current_owner
                current_owner="$(stat -f '%u' "$item" 2>/dev/null || stat -c '%u' "$item" 2>/dev/null)"
                
                if [[ "$current_owner" != "$target_uid" ]]; then
                    if [[ "$dry_run" == "true" ]]; then
                        log_info "[DRY-RUN] Would chown $target_user: $item"
                    else
                        chown "$target_user" "$item" 2>/dev/null || log_warn "Could not chown: $item"
                        log_info "Fixed ownership ($target_user): $item"
                    fi
                    ((chown_count++))
                fi
            done < <(find "$root" \( -type d -o -type f \) ! -user "$target_user" -print0 2>/dev/null)
        fi
    fi
    
    log_info "Summary for $root: dirs=$dir_count, files=$file_count, chown=$chown_count"
}

# =============================================================================
# Main
# =============================================================================
main() {
    local dry_run="false"
    local target_user=""
    local paths=()
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run)
                dry_run="true"
                shift
                ;;
            --user)
                target_user="$2"
                shift 2
                ;;
            --help|-h)
                usage
                ;;
            -*)
                log_error "Unknown option: $1"
                usage
                ;;
            *)
                paths+=("$1")
                shift
                ;;
        esac
    done
    
    # Validate we have at least one path
    if [[ ${#paths[@]} -eq 0 ]]; then
        log_error "At least one path argument is required"
        usage
    fi
    
    # Default to current user if not specified
    if [[ -z "$target_user" ]]; then
        target_user="$(whoami)"
    fi
    
    # Validate all paths first
    for path in "${paths[@]}"; do
        validate_path "$path" || exit 1
    done
    
    # Process each path
    local exit_code=0
    for path in "${paths[@]}"; do
        fix_permissions "$path" "$target_user" "$dry_run" || exit_code=1
    done
    
    if [[ "$dry_run" == "true" ]]; then
        log_info "Dry run complete. No changes were made."
    else
        log_info "Permission fix complete."
    fi
    
    exit $exit_code
}

main "$@"

