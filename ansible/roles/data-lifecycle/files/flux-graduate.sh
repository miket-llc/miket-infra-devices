#!/bin/bash
# Copyright (c) 2025 MikeT LLC. All rights reserved.

# flux-graduate.sh
# Graduating cold data from /flux to /space
# Per DATA_LIFECYCLE_SPEC.md

set -euo pipefail

# =============================================================================
# Configuration
# =============================================================================

FLUX_DIR="/flux/active"
SPACE_DIR="/space/projects"
DAYS_OLD=30
LOG_DIR="${DATA_LIFECYCLE_LOG_DIR:-/space/_ops/logs/data-lifecycle}"
LOG_FILE="${LOG_DIR}/flux-graduate.log"
MARKERS_DIR="${DATA_LIFECYCLE_MARKERS_DIR:-/space/_ops/data-estate/markers}"
MARKER_FILE="${MARKERS_DIR}/flux_graduate.json"
HOSTNAME=$(hostname)

# =============================================================================
# Helper Functions
# =============================================================================

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

# Write marker file (atomic write)
write_marker() {
    local status="$1"
    local message="${2:-}"
    local dirs_graduated="${3:-0}"
    
    mkdir -p "$MARKERS_DIR"
    local temp_file
    temp_file=$(mktemp "${MARKERS_DIR}/.flux_graduate.XXXXXX")
    
    cat > "$temp_file" << EOF
{
  "job": "flux_graduate",
  "host": "${HOSTNAME}",
  "timestamp": "$(date -Iseconds)",
  "source": "${FLUX_DIR}",
  "destination": "${SPACE_DIR}",
  "status": "${status}",
  "message": "${message}",
  "dirs_graduated": ${dirs_graduated}
}
EOF
    
    # Atomic move - only updates marker if write succeeds
    mv "$temp_file" "$MARKER_FILE"
    chmod 644 "$MARKER_FILE"
    log "Marker file updated: ${MARKER_FILE}"
}

# =============================================================================
# Preflight Checks
# =============================================================================

# Ensure log directory exists
mkdir -p "$LOG_DIR"

log "=========================================="
log "Flux Graduation Run Starting"
log "=========================================="

# Check that /flux is mounted and accessible
if [[ ! -d "$FLUX_DIR" ]]; then
    log "ERROR: Flux directory not found: $FLUX_DIR"
    log "ERROR: Is /flux mounted?"
    exit 1
fi

# Check that /space is mounted and writable
if [[ ! -d "$SPACE_DIR" ]]; then
    log "ERROR: Space projects directory not found: $SPACE_DIR"
    log "ERROR: Is /space mounted?"
    exit 1
fi

if [[ ! -w "$SPACE_DIR" ]]; then
    log "ERROR: Space projects directory not writable: $SPACE_DIR"
    exit 1
fi

# =============================================================================
# Main Logic
# =============================================================================

# Create target directory structure
YEAR=$(date +%Y)
DESTINATION="$SPACE_DIR/$YEAR-Graduated"
mkdir -p "$DESTINATION"

log "Source: $FLUX_DIR"
log "Destination: $DESTINATION"
log "Age threshold: $DAYS_OLD days"

GRADUATED_COUNT=0
ERRORS=0

# Find candidates
# Logic: Directories in active root, modified > DAYS_OLD days ago
# Excludes: Directories with .keep-local marker files
shopt -s nullglob
for dir in "$FLUX_DIR"/*/; do
    # Remove trailing slash
    dir="${dir%/}"
    
    # Skip if not a directory (safety check)
    [[ -d "$dir" ]] || continue
    
    # Skip if .keep-local exists
    if [[ -f "$dir/.keep-local" ]]; then
        log "Skipping (has .keep-local): $(basename "$dir")"
        continue
    fi

    # Check modification time
    if [[ $(find "$dir" -maxdepth 0 -mtime +$DAYS_OLD 2>/dev/null) ]]; then
        dirname=$(basename "$dir")
        log "Graduating: $dirname"
        
        # Rsync move (removes source files after successful transfer)
        if rsync -av --remove-source-files "$dir/" "$DESTINATION/$dirname/" >> "$LOG_FILE" 2>&1; then
            # Cleanup empty source directory tree
            find "$dir" -type d -empty -delete 2>/dev/null || true
            log "Completed graduation for $dirname"
            ((GRADUATED_COUNT++))
        else
            EXIT_CODE=$?
            log "ERROR: Failed to graduate $dirname (rsync exit code: $EXIT_CODE)"
            ((ERRORS++))
        fi
    fi
done
shopt -u nullglob

# =============================================================================
# Summary
# =============================================================================

log "=========================================="
log "Graduation Run Complete"
log "Directories graduated: $GRADUATED_COUNT"
log "Errors: $ERRORS"
log "=========================================="

# Write marker based on results
if [[ $ERRORS -gt 0 ]]; then
    write_marker "partial" "Completed with $ERRORS errors" "$GRADUATED_COUNT"
    exit 1
else
    write_marker "success" "Graduated $GRADUATED_COUNT directories" "$GRADUATED_COUNT"
    exit 0
fi
