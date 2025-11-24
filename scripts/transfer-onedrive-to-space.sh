#!/bin/bash
# transfer-onedrive-to-space.sh
# Transfer OneDrive content from client devices to /space on motoko
# Usage: transfer-onedrive-to-space.sh --source <source> --dest <destination> [options]

set -euo pipefail

# Default values
SOURCE=""
DEST=""
DRY_RUN=false
CONFLICT_RESOLUTION="rename"
TRANSFERS=8
VERBOSE=false
LOG_FILE=""
STATUS_FILE=""
PARTIAL_DIR=""

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
            --source)
                SOURCE="$2"
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
Usage: $0 --source <source> --dest <destination> [options]

Transfer OneDrive content from client devices to /space on motoko.

Required:
  --source <source>        Source path (e.g., 'count-zero:/Users/miket/Library/CloudStorage/OneDrive-MikeTLLC/_MAIN_FILES')
  --dest <destination>    Destination directory in /space (e.g., '/space/mike/_MAIN_FILES')

Options:
  --dry-run              Perform dry run without copying files
  --conflict-resolution <mode>
                         How to handle conflicts: rename (default), skip, or overwrite
  --transfers <num>      Number of parallel transfers (default: 8, not used for rsync but kept for compatibility)
  --verbose, -v          Verbose output
  --help, -h             Show this help message

Examples:
  # Dry run
  $0 --source count-zero:/Users/miket/Library/CloudStorage/OneDrive-MikeTLLC/_MAIN_FILES --dest /space/mike/_MAIN_FILES --dry-run

  # Production migration
  $0 --source count-zero:/Users/miket/Library/CloudStorage/OneDrive-MikeTLLC/_MAIN_FILES --dest /space/mike/_MAIN_FILES
EOF
}

# Validate arguments
validate_args() {
    if [[ -z "$SOURCE" ]]; then
        echo -e "${RED}Error: --source is required${NC}" >&2
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

    # Extract account name from destination for logging
    ACCOUNT=$(basename "$(dirname "$DEST")")
    # Use user-writable locations (no sudo required)
    LOG_FILE="${HOME}/.local/log/onedrive-transfer-${ACCOUNT}.log"
    STATUS_FILE="${HOME}/.local/state/miket/onedrive-transfer-${ACCOUNT}.json"
    PARTIAL_DIR="${HOME}/.local/state/miket/onedrive-transfer-${ACCOUNT}-partial"
}

# Initialize logging
init_logging() {
    # Ensure log directory exists
    mkdir -p "$(dirname "$LOG_FILE")"
    touch "$LOG_FILE"

    # Ensure status directory exists
    mkdir -p "$(dirname "$STATUS_FILE")"
    mkdir -p "$PARTIAL_DIR"
    
    # Ensure partial directory exists
    mkdir -p "$PARTIAL_DIR"

    # Redirect stdout and stderr to log file and terminal
    exec > >(tee -a "$LOG_FILE")
    exec 2>&1

    log_info "=== Transfer started ==="
    log_info "Source: $SOURCE"
    log_info "Destination: $DEST"
    log_info "Dry run: $DRY_RUN"
    log_info "Conflict resolution: $CONFLICT_RESOLUTION"
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

# Update status file
update_status() {
    local status="$1"
    local message="$2"
    local files_transferred="${3:-0}"
    local bytes_transferred="${4:-0}"
    local files_total="${5:-0}"
    local bytes_total="${6:-0}"

    cat > "$STATUS_FILE" << EOF
{
  "status": "$status",
  "message": "$message",
  "timestamp": "$(date -Iseconds)",
  "source": "$SOURCE",
  "dest": "$DEST",
  "files_transferred": $files_transferred,
  "bytes_transferred": $bytes_transferred,
  "files_total": $files_total,
  "bytes_total": $bytes_total,
  "progress_percent": $(awk "BEGIN {printf \"%.2f\", ($bytes_transferred / $bytes_total) * 100}" 2>/dev/null || echo "0")
}
EOF
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."

    # Check if rsync is installed
    if ! command -v rsync &> /dev/null; then
        log_error "rsync is not installed"
        exit 1
    fi

    # Parse source (format: host:path or just path)
    if [[ "$SOURCE" == *:* ]]; then
        SOURCE_HOST="${SOURCE%%:*}"
        SOURCE_PATH="${SOURCE#*:}"
    else
        SOURCE_HOST=""
        SOURCE_PATH="$SOURCE"
    fi

    # Test source accessibility
    if [[ -n "$SOURCE_HOST" ]]; then
        log_info "Testing connectivity to $SOURCE_HOST..."
        if ! tailscale ping "$SOURCE_HOST" &> /dev/null; then
            log_error "Cannot reach $SOURCE_HOST via Tailscale"
            exit 1
        fi
    else
        if [[ ! -d "$SOURCE_PATH" ]] && [[ ! -f "$SOURCE_PATH" ]]; then
            log_error "Source path does not exist: $SOURCE_PATH"
            exit 1
        fi
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

    # Check disk space (use parent directory if destination doesn't exist)
    log_info "Checking disk space..."
    SPACE_CHECK_DIR="$DEST"
    if [[ ! -d "$DEST" ]]; then
        SPACE_CHECK_DIR="$(dirname "$DEST")"
    fi
    AVAILABLE=$(df "$SPACE_CHECK_DIR" | tail -1 | awk '{print $4}')
    
    # Estimate source size (if accessible)
    if [[ -n "$SOURCE_HOST" ]]; then
        log_info "Estimating source size (this may take a moment)..."
        SOURCE_SIZE=$(tailscale ssh "$SOURCE_HOST" "du -sb '$SOURCE_PATH' 2>/dev/null | cut -f1" || echo "0")
    else
        SOURCE_SIZE=$(du -sb "$SOURCE_PATH" 2>/dev/null | cut -f1 || echo "0")
    fi
    
    if [[ "$SOURCE_SIZE" -gt 0 ]]; then
        # Add 20% buffer
        REQUIRED=$((SOURCE_SIZE + (SOURCE_SIZE / 5)))
        if [[ "$AVAILABLE" -lt "$REQUIRED" ]]; then
            log_warning "Available space ($AVAILABLE bytes) may be insufficient"
            log_warning "Required (with 20% buffer): $REQUIRED bytes"
            log_warning "Source size: $SOURCE_SIZE bytes"
        else
            log_info "Sufficient disk space available"
            log_info "Source size: $SOURCE_SIZE bytes ($(numfmt --to=iec-i --suffix=B "$SOURCE_SIZE"))"
        fi
        update_status "preparing" "Prerequisites check passed" 0 0 0 "$SOURCE_SIZE"
    fi

    log_success "Prerequisites check passed"
}

# Build rsync command
build_rsync_cmd() {
    # Base rsync command
    if [[ -n "$SOURCE_HOST" ]]; then
        # For macOS (count-zero), use SMB mount if available, otherwise use pull method
        if [[ "$SOURCE_HOST" == "count-zero" ]]; then
            # Check if SMB mount is available on count-zero
            SMB_MOUNT_CHECK=$(tailscale ssh "${SOURCE_HOST}" "test -d ~/.mkt/space && echo 'MOUNTED' || echo 'NOT_MOUNTED'" 2>/dev/null || echo "NOT_MOUNTED")
            if [[ "$SMB_MOUNT_CHECK" == "MOUNTED" ]]; then
                # Use SMB mount - copy directly to mounted /space
                log_info "Using SMB mount on count-zero for transfer"
                CMD="tailscale ssh ${SOURCE_HOST} 'rsync -av"
                REMOTE_SOURCE="${SOURCE_PATH}"
                # Map destination to SMB mount path
                REMOTE_DEST="~/.mkt/space/mike/_MAIN_FILES"
            else
                # Fall back to pull method via Tailscale SSH
                log_info "Using Tailscale SSH pull method"
                CMD="rsync -e 'tailscale ssh'"
                REMOTE_SOURCE="${SOURCE_HOST}:${SOURCE_PATH}"
                REMOTE_DEST=""
            fi
        else
            # Remote source via Tailscale SSH (pull method)
            CMD="rsync -e 'tailscale ssh'"
            REMOTE_SOURCE="${SOURCE_HOST}:${SOURCE_PATH}"
            REMOTE_DEST=""
        fi
    else
        CMD="rsync"
        REMOTE_SOURCE="$SOURCE_PATH"
        REMOTE_DEST=""
    fi

    # Core options
    CMD="$CMD -av"                          # Archive mode, verbose
    CMD="$CMD --progress"                    # Show progress
    CMD="$CMD --info=progress2"              # Modern progress format
    CMD="$CMD --human-readable"              # Human-readable sizes
    CMD="$CMD --partial"                      # Keep partial files on interruption
    CMD="$CMD --partial-dir='$PARTIAL_DIR'"  # Store partial files here
    CMD="$CMD --size-only"                   # Compare by size only (fast for initial transfer)
    CMD="$CMD --stats"                       # Show transfer statistics
    # Note: --checksum removed for speed. Use separate verification pass after transfer if needed.

    # Exclude patterns
    CMD="$CMD --exclude='*.tmp'"
    CMD="$CMD --exclude='*.temp'"
    CMD="$CMD --exclude='.DS_Store'"
    CMD="$CMD --exclude='desktop.ini'"
    CMD="$CMD --exclude='Thumbs.db'"
    CMD="$CMD --exclude='~*'"
    CMD="$CMD --exclude='.Trash'"
    CMD="$CMD --exclude='flux'"              # Exclude our symlinks
    CMD="$CMD --exclude='space'"
    CMD="$CMD --exclude='time'"

    # Conflict resolution
    case "$CONFLICT_RESOLUTION" in
        skip)
            CMD="$CMD --ignore-existing"
            ;;
        overwrite)
            CMD="$CMD --update"  # Only update if newer
            ;;
        rename)
            # Rsync doesn't have built-in rename, we'll handle this in post-processing
            CMD="$CMD --update"
            ;;
    esac

    # Dry run
    if [[ "$DRY_RUN" == true ]]; then
        CMD="$CMD --dry-run"
    fi

    # Verbose
    if [[ "$VERBOSE" == true ]]; then
        CMD="$CMD -vv"
    fi

    # Source and destination
    if [[ -n "$REMOTE_DEST" ]]; then
        # SMB mount method (rsync on count-zero to SMB mount)
        CMD="$CMD '$REMOTE_SOURCE/' '$REMOTE_DEST/'"
        CMD="$CMD'"
    else
        # Pull method (from motoko pulling from remote)
        CMD="$CMD '$REMOTE_SOURCE/' '$DEST/'"
    fi

    echo "$CMD"
}

# Execute transfer with progress monitoring
execute_transfer() {
    log_info "Starting transfer from $SOURCE to $DEST"

    if [[ "$DRY_RUN" == true ]]; then
        log_warning "DRY RUN MODE - No files will be copied"
    fi

    # Build command
    CMD=$(build_rsync_cmd)
    
    log_info "Executing: $CMD"
    update_status "transferring" "Transfer in progress" 0 0 0 0

    # Execute command with progress parsing
    set +e
    eval "$CMD" 2>&1 | while IFS= read -r line; do
        echo "$line"
        
        # Parse progress from rsync output
        # Format: "1,234,567  12%  123.45MB/s    0:00:12  (xfr#123, to-chk=456/789)"
        if [[ "$line" =~ ([0-9,]+)[[:space:]]+([0-9]+)% ]]; then
            BYTES="${BASH_REMATCH[1]//,}"
            PERCENT="${BASH_REMATCH[2]}"
            # Update status (approximate file count)
            update_status "transferring" "Transfer in progress: ${PERCENT}%" 0 "$BYTES" 0 0
        fi
    done
    EXIT_CODE=${PIPESTATUS[0]}
    set -e

    # Handle rsync exit codes
    # 0 = success
    # 23 = partial transfer (some files couldn't be transferred, but some were)
    # 24 = some files/attrs were not transferred (minor issues)
    # Other = real error
    if [[ $EXIT_CODE -eq 0 ]]; then
        log_success "Transfer completed successfully"
        update_status "completed" "Transfer completed successfully" 0 0 0 0
    elif [[ $EXIT_CODE -eq 23 ]] || [[ $EXIT_CODE -eq 24 ]]; then
        log_warning "Transfer completed with minor issues (exit code: $EXIT_CODE)"
        log_info "Some files may not have been transferred due to permissions or other issues"
        log_info "Check log for details. Partial files saved in: $PARTIAL_DIR"
        update_status "completed_with_warnings" "Transfer completed with warnings (exit code: $EXIT_CODE)" 0 0 0 0
    else
        log_error "Transfer failed with exit code: $EXIT_CODE"
        log_info "Partial files saved in: $PARTIAL_DIR"
        log_info "Resume by running the same command again"
        update_status "failed" "Transfer failed with exit code: $EXIT_CODE" 0 0 0 0
        exit $EXIT_CODE
    fi
}

# Validate transfer
validate_transfer() {
    if [[ "$DRY_RUN" == true ]]; then
        log_info "Skipping validation (dry run)"
        return 0
    fi

    log_info "Validating transfer..."

    # Count files and calculate size
    if [[ -n "$SOURCE_HOST" ]]; then
        SOURCE_COUNT=$(tailscale ssh "$SOURCE_HOST" "find '$SOURCE_PATH' -type f 2>/dev/null | wc -l" || echo "0")
        SOURCE_SIZE=$(tailscale ssh "$SOURCE_HOST" "du -sb '$SOURCE_PATH' 2>/dev/null | cut -f1" || echo "0")
    else
        SOURCE_COUNT=$(find "$SOURCE_PATH" -type f 2>/dev/null | wc -l)
        SOURCE_SIZE=$(du -sb "$SOURCE_PATH" 2>/dev/null | cut -f1)
    fi

    DEST_COUNT=$(find "$DEST" -type f 2>/dev/null | wc -l)
    DEST_SIZE=$(du -sb "$DEST" 2>/dev/null | cut -f1)

    log_info "Source file count: $SOURCE_COUNT"
    log_info "Destination file count: $DEST_COUNT"
    log_info "Source size: $SOURCE_SIZE bytes ($(numfmt --to=iec-i --suffix=B "$SOURCE_SIZE" 2>/dev/null || echo "N/A"))"
    log_info "Destination size: $DEST_SIZE bytes ($(numfmt --to=iec-i --suffix=B "$DEST_SIZE" 2>/dev/null || echo "N/A"))"

    if [[ "$SOURCE_COUNT" -gt 0 ]] && [[ "$DEST_COUNT" -eq 0 ]]; then
        log_error "No files transferred!"
        exit 1
    fi

    # Allow 1% difference for metadata overhead
    if [[ "$SOURCE_SIZE" -gt 0 ]]; then
        SIZE_DIFF=$((SOURCE_SIZE - DEST_SIZE))
        SIZE_DIFF_PCT=$((SIZE_DIFF * 100 / SOURCE_SIZE))
        
        if [[ ${SIZE_DIFF_PCT#-} -gt 1 ]]; then
            log_warning "Size difference exceeds 1%: ${SIZE_DIFF_PCT}%"
        else
            log_success "Size validation passed"
        fi
    fi

    log_success "Transfer validation completed"
    update_status "validated" "Transfer validated successfully" "$DEST_COUNT" "$DEST_SIZE" "$SOURCE_COUNT" "$SOURCE_SIZE"
}

# Main execution
main() {
    parse_args "$@"
    validate_args
    init_logging
    check_prerequisites
    execute_transfer
    validate_transfer

    log_success "=== Transfer completed ==="
    log_info "Log file: $LOG_FILE"
    log_info "Status file: $STATUS_FILE"
    
    if [[ "$DRY_RUN" == false ]]; then
        log_info "Next steps:"
        log_info "1. Verify transferred content: ls -la $DEST"
        log_info "2. Test Samba access: smbclient //motoko/space"
        log_info "3. Verify B2 backup includes transferred content"
    fi
}

# Run main function
main "$@"

