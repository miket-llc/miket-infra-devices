#!/bin/bash
# Copyright (c) 2025 MikeT LLC. All rights reserved.

# migrate-onedrive-phased.sh
# Phased migration: count-zero local → /space, then merge cloud-only files
# Ensures no conflicts with hoover/rclone processes
# Usage: migrate-onedrive-phased.sh --account <account> --dest <destination> [options]

set -euo pipefail

# Default values
ACCOUNT=""
DEST=""
DRY_RUN=false
VERBOSE=false
SKIP_CLOUD_MERGE=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --account)
                ACCOUNT="$2"
                shift 2
                ;;
            --dest)
                DEST="$2"
                shift 2
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --skip-cloud-merge)
                SKIP_CLOUD_MERGE=true
                shift
                ;;
            --verbose|-v)
                VERBOSE=true
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

show_help() {
    cat << EOF
Usage: $0 --account <account> --dest <destination> [options]

Phased OneDrive migration: count-zero local → /space, then merge cloud-only files.

Required:
  --account <account>     Account name (e.g., 'mike' or 'miket')
  --dest <destination>    Destination directory in /space (e.g., '/space/mike')

Options:
  --dry-run              Perform dry run without copying files
  --skip-cloud-merge    Skip Phase 2 (cloud merge) - only do local transfer
  --verbose, -v          Verbose output
  --help, -h             Show this help message

Examples:
  # Full migration (local + cloud merge)
  $0 --account miket --dest /space/mike

  # Local transfer only
  $0 --account miket --dest /space/mike --skip-cloud-merge

  # Dry run
  $0 --account miket --dest /space/mike --dry-run
EOF
}

# Validate arguments
validate_args() {
    if [[ -z "$ACCOUNT" ]]; then
        echo -e "${RED}Error: --account is required${NC}" >&2
        show_help
        exit 1
    fi

    if [[ -z "$DEST" ]]; then
        echo -e "${RED}Error: --dest is required${NC}" >&2
        show_help
        exit 1
    fi
}

log_info() {
    echo -e "${CYAN}[$(date '+%Y-%m-%d %H:%M:%S')] $*${NC}"
}

log_error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $*${NC}"
}

log_warning() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: $*${NC}"
}

log_success() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] SUCCESS: $*${NC}"
}

# Check for conflicting processes
check_conflicts() {
    log_info "Checking for conflicting processes..."

    # Check for m365-hoover processes
    if pgrep -f "m365-hoover" > /dev/null; then
        log_warning "m365-hoover process detected. Consider pausing during migration."
        if [[ "$DRY_RUN" == false ]]; then
            read -p "Continue anyway? (y/N) " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                log_error "Migration aborted by user"
                exit 1
            fi
        fi
    fi

    # Check for rclone M365 sync processes
    if pgrep -f "rclone.*m365" > /dev/null; then
        log_warning "Rclone M365 sync process detected. Consider pausing during migration."
        if [[ "$DRY_RUN" == false ]]; then
            read -p "Continue anyway? (y/N) " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                log_error "Migration aborted by user"
                exit 1
            fi
        fi
    fi

    log_success "No active conflicts detected"
}

# Phase 1: Transfer from count-zero local OneDrive
phase1_local_transfer() {
    log_info "=== Phase 1: Transfer from count-zero local OneDrive ==="
    
    # Determine source path based on account
    if [[ "$ACCOUNT" == "mike" ]]; then
        SOURCE_PATH="count-zero:/Users/mike/Library/CloudStorage/OneDrive-MikeTLLC/_MAIN_FILES"
    elif [[ "$ACCOUNT" == "miket" ]]; then
        SOURCE_PATH="count-zero:/Users/miket/Library/CloudStorage/OneDrive-MikeTLLC/_MAIN_FILES"
    else
        log_error "Unknown account: $ACCOUNT. Please specify source path manually."
        exit 1
    fi

    DEST_PATH="${DEST}/_MAIN_FILES"

    log_info "Source: $SOURCE_PATH"
    log_info "Destination: $DEST_PATH"

    # Run transfer script
    TRANSFER_SCRIPT="$(dirname "$0")/transfer-onedrive-to-space.sh"
    if [[ ! -f "$TRANSFER_SCRIPT" ]]; then
        log_error "Transfer script not found: $TRANSFER_SCRIPT"
        exit 1
    fi

    EXTRA_ARGS=""
    if [[ "$DRY_RUN" == true ]]; then
        EXTRA_ARGS="--dry-run"
    fi
    if [[ "$VERBOSE" == true ]]; then
        EXTRA_ARGS="$EXTRA_ARGS --verbose"
    fi

    log_info "Executing transfer script..."
    if bash "$TRANSFER_SCRIPT" --source "$SOURCE_PATH" --dest "$DEST_PATH" $EXTRA_ARGS; then
        log_success "Phase 1 completed: Local transfer from count-zero"
        return 0
    else
        log_error "Phase 1 failed: Local transfer from count-zero"
        return 1
    fi
}

# Phase 2: Merge cloud-only files
phase2_cloud_merge() {
    if [[ "$SKIP_CLOUD_MERGE" == true ]]; then
        log_info "Skipping Phase 2 (cloud merge) as requested"
        return 0
    fi

    log_info "=== Phase 2: Merge cloud-only files from M365 ==="

    # Check if Rclone remote exists
    REMOTE="m365-${ACCOUNT}"
    if ! rclone listremotes | grep -q "^${REMOTE}:$"; then
        log_warning "Rclone remote '${REMOTE}' not found. Skipping cloud merge."
        log_info "To enable cloud merge, configure: rclone config"
        return 0
    fi

    # Test connectivity
    log_info "Testing connectivity to ${REMOTE}..."
    if ! rclone lsd "${REMOTE}:" &> /dev/null; then
        log_warning "Cannot connect to ${REMOTE}. Skipping cloud merge."
        log_info "To enable cloud merge, reconnect: rclone config reconnect ${REMOTE}:"
        return 0
    fi

    log_info "Identifying cloud-only files (not in local transfer)..."

    # Create temporary directory for comparison
    TEMP_DIR=$(mktemp -d)
    trap "rm -rf '$TEMP_DIR'" EXIT

    # List files in cloud
    log_info "Listing files in cloud (this may take a while)..."
    rclone lsf "${REMOTE}:" --recursive > "${TEMP_DIR}/cloud_files.txt" || {
        log_error "Failed to list cloud files"
        return 1
    }

    # List files in local destination
    log_info "Listing files in local destination..."
    find "$DEST" -type f -printf '%P\n' > "${TEMP_DIR}/local_files.txt" 2>/dev/null || touch "${TEMP_DIR}/local_files.txt"

    # Find cloud-only files (files in cloud but not in local)
    log_info "Comparing cloud and local files..."
    comm -23 <(sort "${TEMP_DIR}/cloud_files.txt") <(sort "${TEMP_DIR}/local_files.txt") > "${TEMP_DIR}/cloud_only.txt" || true

    CLOUD_ONLY_COUNT=$(wc -l < "${TEMP_DIR}/cloud_only.txt" | tr -d ' ')
    
    if [[ "$CLOUD_ONLY_COUNT" -eq 0 ]]; then
        log_success "No cloud-only files found. Local transfer is complete."
        return 0
    fi

    log_info "Found $CLOUD_ONLY_COUNT cloud-only files to merge"

    if [[ "$DRY_RUN" == true ]]; then
        log_info "DRY RUN: Would merge $CLOUD_ONLY_COUNT files from cloud"
        head -20 "${TEMP_DIR}/cloud_only.txt" | while read -r file; do
            log_info "  Would merge: $file"
        done
        if [[ "$CLOUD_ONLY_COUNT" -gt 20 ]]; then
            log_info "  ... and $((CLOUD_ONLY_COUNT - 20)) more files"
        fi
        return 0
    fi

    # Merge cloud-only files
    log_info "Merging cloud-only files to $DEST..."
    
    # Use rclone copy (not sync) to merge without deleting
    rclone copy "${REMOTE}:" "$DEST" \
        --checksum \
        --progress \
        --stats \
        --log-file="${HOME}/.local/log/onedrive-cloud-merge-${ACCOUNT}.log" \
        --log-level=INFO \
        --transfers 8 \
        --checkers 16 \
        --fast-list || {
        log_error "Cloud merge failed"
        return 1
    }

    log_success "Phase 2 completed: Cloud-only files merged"
    return 0
}

# Main execution
main() {
    parse_args "$@"
    validate_args

    log_info "=== OneDrive Phased Migration ==="
    log_info "Account: $ACCOUNT"
    log_info "Destination: $DEST"
    log_info "Dry run: $DRY_RUN"
    log_info "Skip cloud merge: $SKIP_CLOUD_MERGE"

    # Check for conflicts
    check_conflicts

    # Phase 1: Local transfer
    if ! phase1_local_transfer; then
        log_error "Migration failed at Phase 1"
        exit 1
    fi

    # Phase 2: Cloud merge
    if ! phase2_cloud_merge; then
        log_error "Migration failed at Phase 2"
        exit 1
    fi

    log_success "=== Migration completed successfully ==="
    log_info "Next steps:"
    log_info "1. Verify migrated content: ls -la $DEST"
    log_info "2. Test Samba access: smbclient //motoko/space"
    log_info "3. Verify B2 backup includes migrated content"
    log_info "4. Resume hoover/rclone processes if paused"
}

# Run main function
main "$@"



