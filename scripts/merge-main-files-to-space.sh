#!/bin/bash
# merge-main-files-to-space.sh
# Merge _MAIN_FILES contents into /space/mike after migration
# Handles conflicts by merging directories and renaming files if needed
# Usage: merge-main-files-to-space.sh --dest /space/mike [options]

set -euo pipefail

# Default values
DEST=""
DRY_RUN=false
CONFLICT_RESOLUTION="merge"  # merge, rename, or skip
VERBOSE=false

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
Usage: $0 --dest <destination> [options]

Merge _MAIN_FILES contents into /space/mike after migration.

Required:
  --dest <destination>    Base destination directory (e.g., '/space/mike')

Options:
  --dry-run              Perform dry run without moving files
  --conflict-resolution <mode>
                         How to handle conflicts: merge (default), rename, or skip
  --verbose, -v          Verbose output
  --help, -h             Show this help message

Examples:
  # Dry run
  $0 --dest /space/mike --dry-run

  # Production merge
  $0 --dest /space/mike

  # Merge with rename conflicts
  $0 --dest /space/mike --conflict-resolution rename
EOF
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

# Validate arguments
validate_args() {
    if [[ -z "$DEST" ]]; then
        echo -e "${RED}Error: --dest is required${NC}" >&2
        show_help
        exit 1
    fi

    if [[ ! -d "$DEST" ]]; then
        log_error "Destination directory does not exist: $DEST"
        exit 1
    fi

    if [[ ! -d "${DEST}/_MAIN_FILES" ]]; then
        log_error "_MAIN_FILES directory not found: ${DEST}/_MAIN_FILES"
        log_info "Migration may not be complete yet"
        exit 1
    fi

    case "$CONFLICT_RESOLUTION" in
        merge|rename|skip)
            ;;
        *)
            log_error "Invalid conflict resolution mode: $CONFLICT_RESOLUTION"
            echo "Valid modes: merge, rename, skip"
            exit 1
            ;;
    esac
}

# Merge a directory from _MAIN_FILES to destination
merge_directory() {
    local source_dir="$1"
    local dest_dir="$2"
    local dir_name=$(basename "$source_dir")

    if [[ "$DRY_RUN" == true ]]; then
        log_info "Would merge: $source_dir -> $dest_dir"
        return 0
    fi

    if [[ ! -d "$dest_dir" ]]; then
        # No conflict - just move it
        log_info "Moving $dir_name (no conflict)"
        mv "$source_dir" "$dest_dir"
        return 0
    fi

    # Conflict exists - handle based on resolution mode
    case "$CONFLICT_RESOLUTION" in
        merge)
            log_info "Merging $dir_name (directory exists, merging contents)"
            # Use rsync to merge directories
            rsync -av "$source_dir/" "$dest_dir/" || {
                log_error "Failed to merge $dir_name"
                return 1
            }
            # Remove source after successful merge
            rm -rf "$source_dir"
            ;;
        rename)
            log_info "Renaming $dir_name (directory exists)"
            local timestamp=$(date +%Y%m%d-%H%M%S)
            local new_name="${dir_name}.from-main-files-${timestamp}"
            mv "$source_dir" "${dest_dir%/*}/${new_name}"
            log_info "Renamed to: $new_name"
            ;;
        skip)
            log_warning "Skipping $dir_name (directory exists)"
            return 0
            ;;
    esac
}

# Merge files from _MAIN_FILES to destination
merge_files() {
    local main_files_dir="${DEST}/_MAIN_FILES"
    local conflicts=0
    local merged=0
    local skipped=0

    log_info "=== Starting merge operation ==="
    log_info "Source: $main_files_dir"
    log_info "Destination: $DEST"
    log_info "Conflict resolution: $CONFLICT_RESOLUTION"
    log_info "Dry run: $DRY_RUN"

    # Process each top-level item in _MAIN_FILES
    while IFS= read -r item; do
        [[ -z "$item" ]] && continue
        
        local item_name=$(basename "$item")
        local dest_item="${DEST}/${item_name}"

        if [[ -d "$item" ]]; then
            # It's a directory
            if [[ -d "$dest_item" ]]; then
                # Conflict
                conflicts=$((conflicts + 1))
                log_warning "Conflict detected: $item_name"
                merge_directory "$item" "$dest_item"
            else
                # No conflict - move it
                merged=$((merged + 1))
                if [[ "$DRY_RUN" == false ]]; then
                    mv "$item" "$dest_item"
                    log_info "Moved directory: $item_name"
                else
                    log_info "Would move directory: $item_name"
                fi
            fi
        elif [[ -f "$item" ]]; then
            # It's a file
            if [[ -f "$dest_item" ]]; then
                # Conflict - check if files are identical
                conflicts=$((conflicts + 1))
                log_info "File conflict: $item_name - checking if identical..."
                
                # Calculate checksums
                local source_hash=""
                local dest_hash=""
                
                if command -v sha256sum &> /dev/null; then
                    source_hash=$(sha256sum "$item" | cut -d' ' -f1)
                    dest_hash=$(sha256sum "$dest_item" | cut -d' ' -f1)
                elif command -v md5sum &> /dev/null; then
                    source_hash=$(md5sum "$item" | cut -d' ' -f1)
                    dest_hash=$(md5sum "$dest_item" | cut -d' ' -f1)
                elif command -v shasum &> /dev/null; then
                    source_hash=$(shasum -a 256 "$item" 2>/dev/null | cut -d' ' -f1 || shasum "$item" | cut -d' ' -f1)
                    dest_hash=$(shasum -a 256 "$dest_item" 2>/dev/null | cut -d' ' -f1 || shasum "$dest_item" | cut -d' ' -f1)
                else
                    log_warning "No checksum tool available (sha256sum/md5sum/shasum) - cannot verify file identity"
                    source_hash="unknown"
                    dest_hash="different"
                fi
                
                if [[ "$source_hash" == "$dest_hash" ]] && [[ "$source_hash" != "unknown" ]]; then
                    # Files are identical - keep the one with older modification date
                    local source_mtime=$(stat -c %Y "$item" 2>/dev/null || stat -f %m "$item" 2>/dev/null || echo "0")
                    local dest_mtime=$(stat -c %Y "$dest_item" 2>/dev/null || stat -f %m "$dest_item" 2>/dev/null || echo "0")
                    
                    if [[ "$source_mtime" -lt "$dest_mtime" ]]; then
                        # Source file is older - replace destination with source (preserve older date)
                        log_info "Files are identical - source has older date, replacing destination"
                        if [[ "$DRY_RUN" == false ]]; then
                            # Copy source over destination to preserve older date
                            cp -p "$item" "$dest_item"
                            rm "$item"
                            log_info "Replaced with older-dated file"
                        else
                            log_info "Would replace with older-dated file (source: $(date -d "@$source_mtime" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date -r "$source_mtime" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "unknown"), dest: $(date -d "@$dest_mtime" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date -r "$dest_mtime" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "unknown"))"
                        fi
                        merged=$((merged + 1))
                    else
                        # Destination file is older - keep it, remove source
                        log_info "Files are identical - destination has older date, keeping destination"
                        if [[ "$DRY_RUN" == false ]]; then
                            rm "$item"
                            log_info "Removed duplicate (kept older file)"
                        else
                            log_info "Would remove duplicate (destination is older)"
                        fi
                        skipped=$((skipped + 1))
                    fi
                else
                    # Files are different - handle based on conflict resolution
                    log_warning "Files differ - $item_name"
                    case "$CONFLICT_RESOLUTION" in
                        merge|rename)
                            local timestamp=$(date +%Y%m%d-%H%M%S)
                            local new_name="${item_name}.from-main-files-${timestamp}"
                            if [[ "$DRY_RUN" == false ]]; then
                                mv "$item" "${DEST}/${new_name}"
                                log_info "Renamed to: $new_name (files differ)"
                            else
                                log_info "Would rename to: $new_name (files differ)"
                            fi
                            ;;
                        skip)
                            skipped=$((skipped + 1))
                            log_info "Skipping file: $item_name (files differ)"
                            ;;
                    esac
                fi
            else
                # No conflict - move it
                merged=$((merged + 1))
                if [[ "$DRY_RUN" == false ]]; then
                    mv "$item" "$dest_item"
                    log_info "Moved file: $item_name"
                else
                    log_info "Would move file: $item_name"
                fi
            fi
        fi
    done < <(find "$main_files_dir" -maxdepth 1 -mindepth 1)

    # Summary
    log_info "=== Merge Summary ==="
    log_info "Merged/moved: $merged"
    log_info "Conflicts handled: $conflicts"
    log_info "Skipped: $skipped"
    log_info ""
    log_info "Note: Identical files (same content hash) were resolved by keeping the file with the older modification date"

    # Remove _MAIN_FILES directory if empty
    if [[ "$DRY_RUN" == false ]]; then
        if [[ -z "$(ls -A "$main_files_dir" 2>/dev/null)" ]]; then
            log_info "Removing empty _MAIN_FILES directory"
            rmdir "$main_files_dir"
        else
            log_warning "_MAIN_FILES directory not empty - may have skipped items"
            log_info "Remaining items: $(ls -A "$main_files_dir" | wc -l)"
        fi
    fi

    log_success "Merge operation completed"
}

# Main execution
main() {
    parse_args "$@"
    validate_args
    merge_files
}

# Run main function
main "$@"

