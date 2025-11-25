#!/bin/bash
# Copyright (c) 2025 MikeT LLC. All rights reserved.

# transfer-onedrive-simple.sh
# Simple OneDrive transfer using ditto (macOS native, handles OneDrive better)
# Usage: Run on count-zero: ./transfer-onedrive-simple.sh

set -euo pipefail

SOURCE="/Users/miket/Library/CloudStorage/OneDrive-MikeTLLC/_MAIN_FILES"
DEST="/Users/miket/.mkt/space/mike/_MAIN_FILES"
LOG_FILE="${HOME}/.local/log/onedrive-transfer-simple.log"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" | tee -a "$LOG_FILE"
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
}

log_warning() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: $1" | tee -a "$LOG_FILE"
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

# Check prerequisites
if [[ ! -d "$SOURCE" ]]; then
    log_error "Source directory does not exist: $SOURCE"
    exit 1
fi

if [[ ! -d "$(dirname "$DEST")" ]]; then
    log_error "Destination parent directory does not exist: $(dirname "$DEST")"
    exit 1
fi

# Ensure log directory exists
mkdir -p "$(dirname "$LOG_FILE")"

log "Starting simple OneDrive transfer"
log "Source: $SOURCE"
log "Destination: $DEST"

# Check disk space
SOURCE_SIZE=$(du -sk "$SOURCE" | cut -f1)
AVAILABLE=$(df -k "$(dirname "$DEST")" | tail -1 | awk '{print $4}')

if [[ "$AVAILABLE" -lt "$SOURCE_SIZE" ]]; then
    log_warning "Available space may be insufficient"
    log "Source size: $(numfmt --to=iec-i --suffix=B $((SOURCE_SIZE * 1024)) 2>/dev/null || echo "${SOURCE_SIZE}KB")"
    log "Available: $(numfmt --to=iec-i --suffix=B $((AVAILABLE * 1024)) 2>/dev/null || echo "${AVAILABLE}KB")"
fi

# Create destination if it doesn't exist
mkdir -p "$DEST"

# Use ditto (macOS native, handles OneDrive better than rsync)
log "Using ditto to copy files (handles OneDrive file system better)"
log "This may take a while for 277K files..."

# ditto options:
# -V: verbose
# -X: exclude resource forks and extended attributes (faster, but we want them)
# -k: create PKZip archive (not needed)
# Just use basic ditto - it handles OneDrive files well
ditto -V "$SOURCE" "$DEST" 2>&1 | tee -a "$LOG_FILE" || {
    EXIT_CODE=$?
    log_error "ditto failed with exit code: $EXIT_CODE"
    log "Check log for details: $LOG_FILE"
    exit $EXIT_CODE
}

log "Transfer completed successfully"
log "Final size: $(du -sh "$DEST" | cut -f1)"
log "Log file: $LOG_FILE"



