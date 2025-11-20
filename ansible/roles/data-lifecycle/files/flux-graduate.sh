#!/bin/bash
# flux-graduate.sh
# Graduating cold data from /flux to /space
# Per DATA_LIFECYCLE_SPEC.md

set -euo pipefail

# Configuration
FLUX_DIR="/flux/active"
SPACE_DIR="/space/projects"
DAYS_OLD=30
LOG_FILE="/var/log/flux-graduate.log"

# Create target directory structure
YEAR=$(date +%Y)
DESTINATION="$SPACE_DIR/$YEAR-Graduated"
mkdir -p "$DESTINATION"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "Starting Flux Graduation Run..."

# Find candidates
# Logic: Directories in active root, modified > 30 days ago
# Excludes: .keep-local files
find "$FLUX_DIR" -maxdepth 1 -mindepth 1 -type d | while read -r dir; do
    # Skip if .keep-local exists
    if [[ -f "$dir/.keep-local" ]]; then
        continue
    fi

    # Check modification time (mtime) of the directory itself
    # Note: Ideally we check contents, but simple directory age is the MVP spec
    if [[ $(find "$dir" -maxdepth 0 -mtime +$DAYS_OLD) ]]; then
        dirname=$(basename "$dir")
        log "Graduating: $dirname"
        
        # Rsync move
        rsync -av --remove-source-files "$dir/" "$DESTINATION/$dirname/" >> "$LOG_FILE" 2>&1
        
        # Cleanup empty source directory
        find "$dir" -type d -empty -delete
        
        log "Completed graduation for $dirname"
    fi
done

log "Graduation Run Complete."

