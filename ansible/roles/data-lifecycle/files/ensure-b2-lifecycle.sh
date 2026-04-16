#!/usr/bin/env bash
# Copyright (c) 2025 MikeT LLC. All rights reserved.
#
# ensure-b2-lifecycle.sh
#
# Asserts the B2 bucket lifecycle policy for the space mirror. Idempotent —
# reads current policy, diffs against desired, only writes if different.
#
# Without an adequate retention window on hide markers, a buggy sync (excludes
# mistake, source remount, hardware failure) can permanently destroy the
# off-site copy before anyone notices. 30 days gives a weekly restore-test +
# Prometheus regression alert plenty of time to flag the problem while the
# data is still recoverable.
#
# Usage: env vars B2_APPLICATION_KEY_ID / B2_APPLICATION_KEY must be set
# (e.g. via /etc/miket/storage-credentials.env, synced from AKV).

set -euo pipefail

BUCKET="${B2_BUCKET:-miket-space-mirror}"
DEST=":b2:${BUCKET}"
DESIRED_HIDE_DAYS="${B2_LIFECYCLE_HIDE_DAYS:-30}"

if [[ -z "${B2_APPLICATION_KEY_ID:-}" ]] || [[ -z "${B2_APPLICATION_KEY:-}" ]]; then
    echo "ERROR: B2_APPLICATION_KEY_ID / B2_APPLICATION_KEY must be set" >&2
    exit 2
fi

export RCLONE_B2_ACCOUNT="$B2_APPLICATION_KEY_ID"
export RCLONE_B2_KEY="$B2_APPLICATION_KEY"

current_json=$(rclone backend lifecycle "$DEST" 2>/dev/null || echo '[]')
current_hide_days=$(echo "$current_json" \
    | grep -oE '"daysFromHidingToDeleting":[[:space:]]*[0-9]+' \
    | head -1 \
    | grep -oE '[0-9]+$' \
    || echo "0")

if [[ "$current_hide_days" == "$DESIRED_HIDE_DAYS" ]]; then
    echo "b2 lifecycle: bucket=$BUCKET daysFromHidingToDeleting=$current_hide_days (unchanged)"
    exit 0
fi

echo "b2 lifecycle: bucket=$BUCKET daysFromHidingToDeleting: $current_hide_days -> $DESIRED_HIDE_DAYS"
rclone backend lifecycle "$DEST" \
    -o "daysFromHidingToDeleting=${DESIRED_HIDE_DAYS}"
echo "b2 lifecycle: applied"
