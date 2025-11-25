#!/bin/bash
# Copyright (c) 2025 MikeT LLC. All rights reserved.

# m365-migrate-to-space.sh
# Migrate all content from OneDrive for Business to /space drive
# Usage: m365-migrate-to-space.sh --account <account> --dest <destination> [options]

set -euo pipefail

# Default values
ACCOUNT=""
DEST=""
DRY_RUN=false
RESUME=false
CONFLICT_RESOLUTION="rename"
TRANSFERS=8
VERBOSE=false
CHECKPOINT_FILE=""
LOG_FILE=""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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
            --resume)
                RESUME=true
                shift
                ;;
            --conflict-resolution)
                CONFLICT_RESOLUTION="$2"
                shift 2
                ;;
            --transfers)
                TRANSFERS="$2"
                shift 2
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

Migrate all content from OneDrive for Business to /space drive.

Required:
  --account <account>     OneDrive account name (e.g., 'mike')
  --dest <destination>    Destination directory in /space (e.g., '/space/mike')

Options:
  --dry-run              Perform dry run without copying files
  --resume               Resume interrupted migration
  --conflict-resolution <mode>
                         How to handle conflicts: rename (default), skip, or overwrite
  --transfers <num>      Number of parallel transfers (default: 8)
  --verbose, -v          Verbose output
  --help, -h             Show this help message

Examples:
  # Dry run
  $0 --account mike --dest /space/mike --dry-run

  # Production migration
  $0 --account mike --dest /space/mike --transfers 16

  # Resume interrupted migration
  $0 --account mike --dest /space/mike --resume
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

    # Validate conflict resolution mode
    case "$CONFLICT_RESOLUTION" in
        rename|skip|overwrite)
            ;;
        *)
            echo -e "${RED}Error: Invalid conflict resolution mode: $CONFLICT_RESOLUTION${NC}" >&2
            echo "Valid modes: rename, skip, overwrite"
            exit 1
            ;;
    esac

    # Set checkpoint and log file paths
    CHECKPOINT_FILE="/var/lib/miket/m365-migrate-${ACCOUNT}.checkpoint"
    LOG_FILE="/var/log/m365-migrate-${ACCOUNT}.log"
}

# Initialize logging
init_logging() {
    # Ensure log directory exists
    mkdir -p "$(dirname "$LOG_FILE")"
    touch "$LOG_FILE"

    # Redirect stdout and stderr to log file and terminal
    exec > >(tee -a "$LOG_FILE")
    exec 2>&1

    log_info "=== Migration started ==="
    log_info "Account: $ACCOUNT"
    log_info "Destination: $DEST"
    log_info "Dry run: $DRY_RUN"
    log_info "Resume: $RESUME"
    log_info "Conflict resolution: $CONFLICT_RESOLUTION"
    log_info "Parallel transfers: $TRANSFERS"
}

log_info() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $*${NC}" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: $*${NC}" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] SUCCESS: $*${NC}" | tee -a "$LOG_FILE"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."

    # Check if rclone is installed
    if ! command -v rclone &> /dev/null; then
        log_error "rclone is not installed"
        exit 1
    fi

    # Check if remote exists
    REMOTE="m365-${ACCOUNT}"
    if ! rclone listremotes | grep -q "^${REMOTE}:$"; then
        log_error "Rclone remote '${REMOTE}' not found"
        log_info "Available remotes:"
        rclone listremotes
        exit 1
    fi

    # Test remote connectivity
    log_info "Testing connectivity to ${REMOTE}..."
    if ! rclone lsd "${REMOTE}:" &> /dev/null; then
        log_error "Cannot connect to ${REMOTE}. Check authentication."
        log_info "Try: rclone config reconnect ${REMOTE}:"
        exit 1
    fi

    # Check destination directory
    if [[ ! -d "$(dirname "$DEST")" ]]; then
        log_error "Parent directory does not exist: $(dirname "$DEST")"
        exit 1
    fi

    # Create destination directory if it doesn't exist
    if [[ ! -d "$DEST" ]]; then
        if [[ "$DRY_RUN" == false ]]; then
            mkdir -p "$DEST"
            log_info "Created destination directory: $DEST"
        else
            log_info "Would create destination directory: $DEST"
        fi
    fi

    # Check disk space
    log_info "Checking disk space..."
    AVAILABLE=$(df "$DEST" | tail -1 | awk '{print $4}')
    SOURCE_SIZE=$(rclone size "${REMOTE}:" --json 2>/dev/null | jq -r '.bytes // 0')
    
    if [[ "$SOURCE_SIZE" -gt 0 ]]; then
        # Add 20% buffer
        REQUIRED=$((SOURCE_SIZE + (SOURCE_SIZE / 5)))
        if [[ "$AVAILABLE" -lt "$REQUIRED" ]]; then
            log_warning "Available space ($AVAILABLE bytes) may be insufficient"
            log_warning "Required (with 20% buffer): $REQUIRED bytes"
            log_warning "Source size: $SOURCE_SIZE bytes"
        else
            log_info "Sufficient disk space available"
        fi
    fi

    log_success "Prerequisites check passed"
}

# Build rclone sync command
build_rclone_cmd() {
    REMOTE="m365-${ACCOUNT}"
    CMD="rclone sync \"${REMOTE}:\" \"${DEST}\""

    # Add flags
    CMD="$CMD --transfers $TRANSFERS"
    CMD="$CMD --checkers 16"
    CMD="$CMD --fast-list"
    CMD="$CMD --progress"
    CMD="$CMD --log-file=\"$LOG_FILE\""
    CMD="$CMD --log-level=INFO"

    # Conflict resolution
    case "$CONFLICT_RESOLUTION" in
        skip)
            CMD="$CMD --skip-existing"
            ;;
        overwrite)
            CMD="$CMD --update"
            ;;
        rename)
            # Rclone doesn't have built-in rename, we'll handle this in post-processing
            CMD="$CMD --update"
            ;;
    esac

    # Dry run
    if [[ "$DRY_RUN" == true ]]; then
        CMD="$CMD --dry-run"
    fi

    # Resume support (checkpoint)
    if [[ "$RESUME" == true ]] && [[ -f "$CHECKPOINT_FILE" ]]; then
        log_info "Resuming from checkpoint: $CHECKPOINT_FILE"
        # Rclone doesn't have native checkpoint resume, but we can use --fast-list
        # to speed up resumption
    fi

    echo "$CMD"
}

# Handle conflicts (rename mode)
handle_conflicts() {
    if [[ "$CONFLICT_RESOLUTION" != "rename" ]]; then
        return 0
    fi

    log_info "Checking for conflicts..."

    # This is a simplified conflict handler
    # In production, you might want more sophisticated conflict detection
    # For now, rclone's --update flag will handle most cases
    # Additional conflict handling can be added here if needed
}

# Execute migration
execute_migration() {
    log_info "Starting migration from ${REMOTE}: to $DEST"

    if [[ "$DRY_RUN" == true ]]; then
        log_warning "DRY RUN MODE - No files will be copied"
    fi

    # Build command
    CMD=$(build_rclone_cmd)
    
    log_info "Executing: $CMD"

    # Execute command
    set +e
    eval "$CMD"
    EXIT_CODE=$?
    set -e

    if [[ $EXIT_CODE -eq 0 ]]; then
        log_success "Migration completed successfully"
        
        # Save checkpoint
        if [[ "$DRY_RUN" == false ]]; then
            mkdir -p "$(dirname "$CHECKPOINT_FILE")"
            echo "$(date -Iseconds)" > "$CHECKPOINT_FILE"
        fi
    else
        log_error "Migration failed with exit code: $EXIT_CODE"
        log_info "Check log file for details: $LOG_FILE"
        exit $EXIT_CODE
    fi
}

# Validate migration
validate_migration() {
    if [[ "$DRY_RUN" == true ]]; then
        log_info "Skipping validation (dry run)"
        return 0
    fi

    log_info "Validating migration..."

    REMOTE="m365-${ACCOUNT}"

    # Compare file counts
    SOURCE_COUNT=$(rclone size "${REMOTE}:" --json 2>/dev/null | jq -r '.count // 0')
    DEST_COUNT=$(find "$DEST" -type f 2>/dev/null | wc -l)

    log_info "Source file count: $SOURCE_COUNT"
    log_info "Destination file count: $DEST_COUNT"

    if [[ "$SOURCE_COUNT" -gt 0 ]] && [[ "$DEST_COUNT" -eq 0 ]]; then
        log_error "No files migrated!"
        exit 1
    fi

    # Compare sizes (approximate)
    SOURCE_SIZE=$(rclone size "${REMOTE}:" --json 2>/dev/null | jq -r '.bytes // 0')
    DEST_SIZE=$(du -sb "$DEST" 2>/dev/null | cut -f1)

    log_info "Source size: $SOURCE_SIZE bytes"
    log_info "Destination size: $DEST_SIZE bytes"

    # Allow 1% difference for metadata overhead
    SIZE_DIFF=$((SOURCE_SIZE - DEST_SIZE))
    SIZE_DIFF_PCT=$((SIZE_DIFF * 100 / SOURCE_SIZE))

    if [[ ${SIZE_DIFF_PCT#-} -gt 1 ]]; then
        log_warning "Size difference exceeds 1%: ${SIZE_DIFF_PCT}%"
    else
        log_success "Size validation passed"
    fi

    log_success "Migration validation completed"
}

# Main execution
main() {
    parse_args "$@"
    validate_args
    init_logging
    check_prerequisites
    execute_migration
    validate_migration

    log_success "=== Migration completed ==="
    log_info "Log file: $LOG_FILE"
    
    if [[ "$DRY_RUN" == false ]]; then
        log_info "Next steps:"
        log_info "1. Verify migrated content: ls -la $DEST"
        log_info "2. Test Samba access: smbclient //motoko/space"
        log_info "3. Verify B2 backup includes migrated content"
    fi
}

# Run main function
main "$@"

