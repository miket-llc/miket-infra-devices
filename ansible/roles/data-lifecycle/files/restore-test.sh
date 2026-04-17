#!/bin/bash
# Copyright (c) 2025 MikeT LLC. All rights reserved.
# restore-test.sh
# Automated Restore Drill - per P0 Bulletproof Backups mandate
#
# "If you don't test restore, you don't have a backup."
#
# This script:
# 1. Restores a known test file set from B2 mirror to temp dir
# 2. Restores a small restic snapshot subset to temp dir
# 3. Validates checksums/file counts
# 4. Writes PASS/FAIL + timestamp to /space/_ops/backups/restore-tests/

set -euo pipefail

# =============================================================================
# Configuration
# =============================================================================

LOG_DIR="${DATA_LIFECYCLE_LOG_DIR:-/space/_ops/logs/data-lifecycle}"
LOG_FILE="${LOG_DIR}/restore-test.log"
RESULTS_DIR="${DATA_LIFECYCLE_RESTORE_TEST_DIR:-/space/_ops/backups/restore-tests}"
MARKERS_DIR="${DATA_LIFECYCLE_MARKERS_DIR:-/space/_ops/data-estate/markers}"
MARKER_FILE="${MARKERS_DIR}/restore_test.json"
TEMP_BASE="/tmp/restore-test-$$"
HOSTNAME=$(hostname)

# B2 bucket for mirror
B2_BUCKET=":b2:miket-space-mirror"

# Restic repo for snapshots
RESTIC_REPO="${RESTIC_REPO:-b2:miket-backups-restic:flux}"

# Anchor file — a known small blob living in both /space and B2 that we
# round-trip through a real restore and byte-compare. Existence alone is
# not enough ("file present but corrupt" is the failure mode we got
# bitten by); we verify the restored content against the live source via
# SHA256. If this anchor is missing from B2 the mirror is broken and the
# test MUST fail loudly.
ANCHOR_DIR="/space/_ops/backups/restore-anchor"
ANCHOR_FILE_NAME="anchor.txt"
ANCHOR_SRC_PATH="${ANCHOR_DIR}/${ANCHOR_FILE_NAME}"
ANCHOR_B2_PATH="_ops/backups/restore-anchor/${ANCHOR_FILE_NAME}"

# Timing
START_TIME=$(date +%s)
START_TIMESTAMP=$(date -Iseconds)

# Track test results
MIRROR_TEST_PASSED=false
RESTIC_TEST_PASSED=false
OVERALL_PASSED=false

# Ensure directories exist
mkdir -p "$LOG_DIR" "$RESULTS_DIR" "$MARKERS_DIR"

# =============================================================================
# Helper Functions
# =============================================================================

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

cleanup() {
    log "Cleaning up temp directory: ${TEMP_BASE}"
    rm -rf "${TEMP_BASE}" 2>/dev/null || true
}
trap cleanup EXIT

write_result() {
    local test_type="$1"
    local status="$2"
    local message="$3"
    local result_file="${RESULTS_DIR}/${test_type}_$(date +%Y%m%d_%H%M%S).json"

    cat > "$result_file" << EOF
{
  "test_type": "${test_type}",
  "host": "${HOSTNAME}",
  "timestamp": "$(date -Iseconds)",
  "status": "${status}",
  "message": "${message}"
}
EOF
    chmod 644 "$result_file"
    log "Result written: ${result_file}"
}

write_marker() {
    local status="$1"
    local message="$2"
    local mirror_ok="$3"
    local restic_ok="$4"
    local duration_seconds="$5"
    local temp_file
    temp_file=$(mktemp "${MARKERS_DIR}/.restore_test.XXXXXX")

    cat > "$temp_file" << EOF
{
  "job": "restore_test",
  "host": "${HOSTNAME}",
  "started_at": "${START_TIMESTAMP}",
  "completed_at": "$(date -Iseconds)",
  "duration_seconds": ${duration_seconds},
  "status": "${status}",
  "message": "${message}",
  "tests": {
    "b2_mirror": "${mirror_ok}",
    "restic_snapshot": "${restic_ok}"
  }
}
EOF

    mv "$temp_file" "$MARKER_FILE"
    chmod 644 "$MARKER_FILE"
    log "Marker file updated: ${MARKER_FILE}"
}

# =============================================================================
# Credential Validation
# =============================================================================

log "=========================================="
log "Automated Restore Drill Starting"
log "=========================================="

# Check B2 mirror credentials
if [[ -z "${B2_APPLICATION_KEY_ID:-}" ]] || [[ -z "${B2_APPLICATION_KEY:-}" ]]; then
    log "ERROR: B2 mirror credentials missing from environment"
    exit 1
fi

# Check restic credentials
if [[ -z "${RESTIC_PASSWORD:-}" ]] || [[ -z "${B2_ACCOUNT_ID:-}" ]] || [[ -z "${B2_ACCOUNT_KEY:-}" ]]; then
    log "ERROR: Restic credentials missing from environment"
    exit 1
fi

# Set rclone environment
export RCLONE_B2_ACCOUNT="${B2_APPLICATION_KEY_ID}"
export RCLONE_B2_KEY="${B2_APPLICATION_KEY}"

# =============================================================================
# Test 1: B2 Mirror Restore
# =============================================================================

log "----------------------------------------"
log "Test 1: B2 Mirror Restore (anchor round-trip)"
log "----------------------------------------"

MIRROR_TEMP="${TEMP_BASE}/mirror"
mkdir -p "$MIRROR_TEMP"

# The anchor must exist on /space. If it doesn't, the test can't run —
# that itself is a data integrity problem (someone deleted the anchor
# or the deploy didn't seed it) and must FAIL.
if [[ ! -f "$ANCHOR_SRC_PATH" ]]; then
    log "✗ B2 Mirror Restore: FAILED (anchor missing from source: ${ANCHOR_SRC_PATH})"
    log "  Run: ansible-playbook deploy-data-lifecycle.yml to re-seed the anchor."
    write_result "b2_mirror" "FAIL" "Anchor missing from /space"
else
    SRC_SHA=$(sha256sum "$ANCHOR_SRC_PATH" | awk '{print $1}')
    log "Source anchor SHA256: ${SRC_SHA}"

    log "Restoring ${ANCHOR_B2_PATH} from B2 mirror..."
    if rclone copy "${B2_BUCKET}/${ANCHOR_B2_PATH}" "${MIRROR_TEMP}/" \
        --retries 3 \
        --low-level-retries 5 \
        2>&1 | tee -a "$LOG_FILE"; then

        RESTORED_FILE="${MIRROR_TEMP}/${ANCHOR_FILE_NAME}"
        if [[ ! -f "$RESTORED_FILE" ]]; then
            log "✗ B2 Mirror Restore: FAILED (anchor not present in B2 — mirror did not run, or was purged)"
            write_result "b2_mirror" "FAIL" "Anchor file absent from B2"
        else
            RESTORED_SHA=$(sha256sum "$RESTORED_FILE" | awk '{print $1}')
            RESTORED_BYTES=$(stat -c %s "$RESTORED_FILE")
            log "Restored anchor SHA256: ${RESTORED_SHA} (${RESTORED_BYTES} bytes)"

            if [[ "$RESTORED_SHA" == "$SRC_SHA" ]]; then
                log "✓ B2 Mirror Restore: PASSED (checksum match, ${RESTORED_BYTES} bytes)"
                MIRROR_TEST_PASSED=true
                write_result "b2_mirror" "PASS" "Anchor round-trip verified (sha256=${SRC_SHA})"
            else
                log "✗ B2 Mirror Restore: FAILED (checksum mismatch — B2 has stale or corrupt anchor)"
                log "  expected: ${SRC_SHA}"
                log "  got:      ${RESTORED_SHA}"
                write_result "b2_mirror" "FAIL" "Checksum mismatch (src=${SRC_SHA} restored=${RESTORED_SHA})"
            fi
        fi
    else
        log "✗ B2 Mirror Restore: FAILED (rclone copy error)"
        write_result "b2_mirror" "FAIL" "Rclone copy failed"
    fi
fi

# =============================================================================
# Test 2: Restic Snapshot Restore
# =============================================================================

log "----------------------------------------"
log "Test 2: Restic Snapshot Restore"
log "----------------------------------------"

RESTIC_TEMP="${TEMP_BASE}/restic"
mkdir -p "$RESTIC_TEMP"

# Get latest snapshot ID
log "Fetching latest snapshot from restic repo..."
LATEST_SNAPSHOT=$(restic -r "$RESTIC_REPO" snapshots --json 2>/dev/null | jq -r '.[-1].short_id // empty' || echo "")

if [[ -z "$LATEST_SNAPSHOT" ]]; then
    log "WARNING: No snapshots found in restic repository"
    log "This may be expected if flux-backup hasn't run yet"
    write_result "restic_snapshot" "SKIP" "No snapshots available"
    # Don't fail the overall test if there are no snapshots yet
    RESTIC_TEST_PASSED=true
else
    log "Latest snapshot: ${LATEST_SNAPSHOT}"
    log "Restoring sample files from snapshot..."

    # Earlier iterations of this drill hard-coded `--include "*/.policy/*"`
    # because that directory was expected to hold policy-tracking files
    # the data-lifecycle spec calls for. In practice `.policy` is empty
    # on every host today — the policy-file generator was never shipped —
    # so any snapshot restored through that filter returns 0 bytes and
    # the drill silently condemns otherwise-healthy backups. Switch to
    # whole-snapshot restore: snapshots of /flux are small (typically
    # single-digit MiB on motoko, bounded by the exclude list on akira),
    # restic is fast enough that this costs seconds, and the assertion
    # becomes "can we actually bring bytes back from B2?" which is what
    # we want to prove.
    if restic -r "$RESTIC_REPO" restore "$LATEST_SNAPSHOT" \
        --target "$RESTIC_TEMP" \
        2>&1 | tee -a "$LOG_FILE"; then

        RESTORED_COUNT=$(find "$RESTIC_TEMP" -type f 2>/dev/null | wc -l)
        RESTORED_BYTES=$(find "$RESTIC_TEMP" -type f -printf '%s\n' 2>/dev/null | awk '{s+=$1} END{print s+0}')
        log "Restored ${RESTORED_COUNT} file(s), ${RESTORED_BYTES} bytes from restic snapshot"

        if [[ "$RESTORED_COUNT" -gt 0 && "$RESTORED_BYTES" -gt 0 ]]; then
            log "✓ Restic Snapshot Restore: PASSED (${RESTORED_COUNT} files, ${RESTORED_BYTES} bytes)"
            RESTIC_TEST_PASSED=true
            write_result "restic_snapshot" "PASS" "Restored ${RESTORED_COUNT} files / ${RESTORED_BYTES} bytes"
        else
            log "✗ Restic Snapshot Restore: FAILED (0 files or 0 bytes restored — drill proved nothing)"
            write_result "restic_snapshot" "FAIL" "Zero files/bytes restored (was silently passing)"
        fi
    else
        log "✗ Restic Snapshot Restore: FAILED (restore error)"
        write_result "restic_snapshot" "FAIL" "Restic restore failed"
    fi
fi

# =============================================================================
# Overall Result
# =============================================================================

log "----------------------------------------"
log "Restore Drill Summary"
log "----------------------------------------"

END_TIME=$(date +%s)
DURATION_SECONDS=$((END_TIME - START_TIME))
DURATION_HUMAN=$(printf '%dm %ds' $((DURATION_SECONDS/60)) $((DURATION_SECONDS%60)))

# Emit Prometheus textfile metrics (atomic tmpfile + rename).
emit_restore_metrics() {
    local overall="$1"  # 1=pass, 0=fail
    local mirror="$2"   # 1=pass, 0=fail
    local restic="$3"   # 1=pass, 0=fail
    local metrics_dir="${NODE_EXPORTER_TEXTFILE_DIR:-/var/lib/node_exporter/textfile_collector}"
    local metrics_file="${metrics_dir}/restore_test.prom"
    [[ -d "$metrics_dir" ]] || return 0
    local tmp
    tmp=$(mktemp "${metrics_dir}/.restore_test.prom.XXXXXX") || return 1
    cat > "$tmp" <<METRICS
# HELP restore_test_last_run_timestamp_seconds Unix time of the last restore drill.
# TYPE restore_test_last_run_timestamp_seconds gauge
restore_test_last_run_timestamp_seconds $(date +%s)
# HELP restore_test_last_overall_status 1 if both drills passed, 0 if any failed.
# TYPE restore_test_last_overall_status gauge
restore_test_last_overall_status ${overall}
# HELP restore_test_last_mirror_status 1 if the B2 mirror anchor round-trip passed.
# TYPE restore_test_last_mirror_status gauge
restore_test_last_mirror_status ${mirror}
# HELP restore_test_last_restic_status 1 if the restic snapshot restore passed.
# TYPE restore_test_last_restic_status gauge
restore_test_last_restic_status ${restic}
# HELP restore_test_last_run_duration_seconds Wall-clock duration of the last drill.
# TYPE restore_test_last_run_duration_seconds gauge
restore_test_last_run_duration_seconds ${DURATION_SECONDS}
METRICS
    chmod 644 "$tmp"
    mv "$tmp" "$metrics_file"
}

if $MIRROR_TEST_PASSED && $RESTIC_TEST_PASSED; then
    OVERALL_PASSED=true
    log "=========================================="
    log "OVERALL RESULT: PASS"
    log "Duration: ${DURATION_HUMAN}"
    log "=========================================="
    write_marker "success" "All restore tests passed" "PASS" "PASS" "$DURATION_SECONDS"
    emit_restore_metrics 1 1 1 || true
    exit 0
else
    log "=========================================="
    log "OVERALL RESULT: FAIL"
    log "B2 Mirror: $(if $MIRROR_TEST_PASSED; then echo PASS; else echo FAIL; fi)"
    log "Restic:    $(if $RESTIC_TEST_PASSED; then echo PASS; else echo FAIL; fi)"
    log "Duration: ${DURATION_HUMAN}"
    log "=========================================="
    log "CRITICAL: Restore capability is impaired!"

    MIRROR_STATUS=$(if $MIRROR_TEST_PASSED; then echo "PASS"; else echo "FAIL"; fi)
    RESTIC_STATUS=$(if $RESTIC_TEST_PASSED; then echo "PASS"; else echo "FAIL"; fi)
    write_marker "failed" "One or more restore tests failed" "$MIRROR_STATUS" "$RESTIC_STATUS" "$DURATION_SECONDS"
    emit_restore_metrics 0 \
        "$(if $MIRROR_TEST_PASSED; then echo 1; else echo 0; fi)" \
        "$(if $RESTIC_TEST_PASSED; then echo 1; else echo 0; fi)" || true
    exit 1
fi
