---
document_title: "B2 Space Mirror Implementation Review"
author: "Codex-CA-001 (Chief Architect)"
last_updated: 2025-11-23
status: Published
related_initiatives:
  - data-lifecycle-automation
linked_communications:
  - docs/communications/COMMUNICATION_LOG.md#2025-11-23-b2-sync-review
---

# B2 Space Mirror Implementation Review

## Executive Summary

**Status:** ✅ **ACCEPTABLE WITH RECOMMENDATIONS**

The current `space-mirror.sh` implementation is **functionally correct** and aligns with PHC patterns, but has opportunities for improvement in error handling, observability, and potential simplification.

**Key Findings:**
- ✅ Secrets management correctly uses AKV → `.env` → `EnvironmentFile` pattern
- ✅ Consistent with existing `flux-backup.sh` pattern
- ⚠️ Minimal error handling and exit code propagation
- ⚠️ Thin wrapper script could be simplified
- ⚠️ No observability/metrics hooks
- ✅ Aligns with `DATA_LIFECYCLE_SPEC.md` requirements

**Recommendation:** Keep custom script pattern for consistency, but enhance error handling and add observability hooks.

---

## Current Implementation Analysis

### Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│ Azure Key Vault (kv-miket-ops)                          │
│   └─ b2-space-mirror-id / b2-space-mirror-key            │
└──────────────────┬──────────────────────────────────────┘
                   │
                   │ (secrets-sync.yml)
                   ▼
┌─────────────────────────────────────────────────────────┐
│ /etc/miket/storage-credentials.env (0600)               │
│   └─ B2_APPLICATION_KEY_ID, B2_APPLICATION_KEY           │
└──────────────────┬──────────────────────────────────────┘
                   │
                   │ (EnvironmentFile)
                   ▼
┌─────────────────────────────────────────────────────────┐
│ space-mirror.service (systemd)                          │
│   └─ ExecStart=/usr/local/bin/space-mirror.sh           │
└──────────────────┬──────────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────────┐
│ space-mirror.sh (bash wrapper)                          │
│   ├─ Sets RCLONE_B2_* env vars                          │
│   ├─ Calls rclone sync /space :b2:miket-space-mirror    │
│   └─ Logs to /var/log/space-mirror.log                  │
└──────────────────┬──────────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────────┐
│ Backblaze B2: miket-space-mirror                        │
└─────────────────────────────────────────────────────────┘
```

### Code Review

**File:** `ansible/roles/data-lifecycle/files/space-mirror.sh`

**Strengths:**
1. ✅ Uses environment-based rclone backend (`:b2:miket-space-mirror`) - no config file needed
2. ✅ Secrets sourced from AKV via `EnvironmentFile` (PHC invariant #3 compliant)
3. ✅ Consistent pattern with `flux-backup.sh` and `flux-local-snap.sh`
4. ✅ Proper logging to `/var/log/space-mirror.log`
5. ✅ Uses `set -euo pipefail` for error handling
6. ✅ Aligns with `DATA_LIFECYCLE_SPEC.md` §2.C requirements

**Weaknesses:**
1. ⚠️ No explicit exit code handling - rclone exit codes not checked
2. ⚠️ No error notification or alerting hooks
3. ⚠️ Minimal script value - mostly just sets env vars and calls rclone
4. ⚠️ No metrics/observability (duration, bytes transferred, success/failure)
5. ⚠️ Environment variable fallback logic (`${B2_APPLICATION_KEY_ID:-$B2_ACCOUNT_ID:-}`) is confusing

### Comparison with Alternatives

#### Option A: Current Custom Script (✅ RECOMMENDED)
**Pros:**
- Consistent with `flux-backup.sh` pattern
- Centralized logging setup
- Environment variable normalization
- Easy to add hooks (notifications, metrics) later

**Cons:**
- Thin wrapper adds minimal value
- Requires script maintenance

#### Option B: Direct systemd ExecStart
**Pros:**
- Simpler, fewer moving parts
- No wrapper script to maintain

**Cons:**
- Breaks consistency with other backup scripts
- Harder to add error handling/observability later
- Long ExecStart line in systemd unit

**Example:**
```ini
[Service]
ExecStart=/usr/bin/rclone sync /space :b2:miket-space-mirror \
    --fast-list \
    --transfers 16 \
    --track-renames \
    --log-file=/var/log/space-mirror.log \
    --log-level=INFO
```

#### Option C: Rclone Native systemd Integration
**Assessment:** Rclone doesn't provide native systemd integration. Custom script or direct ExecStart are the only options.

---

## PHC Invariant Compliance

### ✅ Invariant #1: Storage & Filesystem
- `/space` is System of Record (SoR) ✅
- One-way sync: `/space` → B2 (no circular loops) ✅
- B2 is backup/mirror, not primary SoR ✅

### ✅ Invariant #3: Secrets Architecture
- Secrets from Azure Key Vault (`kv-miket-ops`) ✅
- Synced to `/etc/miket/storage-credentials.env` via `secrets-sync.yml` ✅
- EnvironmentFile in systemd unit ✅
- No hardcoded secrets ✅

### ✅ Invariant #4: Documentation
- Spec documented in `DATA_LIFECYCLE_SPEC.md` ✅
- Script references spec in header ✅

### ✅ Invariant #7: Alignment Between "infra" and "devices"
- B2 bucket defined in `miket-infra` (Terraform) ✅
- Automation in `miket-infra-devices` (Ansible) ✅
- Clear separation of concerns ✅

---

## Recommendations

### Priority 1: Error Handling Enhancement

**Current Issue:** Script doesn't check rclone exit codes or propagate failures.

**Fix:**
```bash
#!/bin/bash
# space-mirror.sh
# 1:1 Mirror of /space to B2
# Per DATA_LIFECYCLE_SPEC.md

set -euo pipefail

SOURCE="/space"
DEST=":b2:miket-space-mirror"
LOG_FILE="/var/log/space-mirror.log"

# Rclone Configuration (environment based for safety)
export RCLONE_B2_HARD_DELETE=true
export RCLONE_B2_ACCOUNT="${B2_APPLICATION_KEY_ID}"
export RCLONE_B2_KEY="${B2_APPLICATION_KEY}"

echo "[$(date)] Starting Space Mirror..." >> "$LOG_FILE"

# Run rclone and capture exit code
if rclone sync "$SOURCE" "$DEST" \
    --fast-list \
    --transfers 16 \
    --track-renames \
    --log-file="$LOG_FILE" \
    --log-level=INFO \
    2>> "$LOG_FILE"; then
    echo "[$(date)] Space Mirror Complete." >> "$LOG_FILE"
    exit 0
else
    EXIT_CODE=$?
    echo "[$(date)] Space Mirror FAILED with exit code $EXIT_CODE" >> "$LOG_FILE"
    exit $EXIT_CODE
fi
```

### Priority 2: Environment Variable Simplification

**Current Issue:** Confusing fallback logic with `:-` operator.

**Fix:** Remove fallback - rely on `secrets-sync.yml` to provide correct variables:
```bash
# Fail fast if secrets are missing
if [[ -z "${B2_APPLICATION_KEY_ID:-}" ]] || [[ -z "${B2_APPLICATION_KEY:-}" ]]; then
    echo "[$(date)] ERROR: B2 credentials missing from environment" >> "$LOG_FILE"
    exit 1
fi

export RCLONE_B2_ACCOUNT="${B2_APPLICATION_KEY_ID}"
export RCLONE_B2_KEY="${B2_APPLICATION_KEY}"
```

### Priority 3: Observability Hooks (Future Enhancement)

**Add metrics/notification hooks:**
```bash
# After successful sync
if command -v systemd-notify >/dev/null 2>&1; then
    systemd-notify --status="Space mirror completed successfully"
fi

# Optional: Send notification on failure
if [[ $EXIT_CODE -ne 0 ]] && command -v notify-send >/dev/null 2>&1; then
    notify-send "Space Mirror Failed" "Exit code: $EXIT_CODE" || true
fi
```

### Priority 4: Consider Direct systemd ExecStart (Optional)

**If consistency with other scripts isn't critical**, simplify to direct systemd ExecStart:

```ini
[Service]
Type=oneshot
EnvironmentFile=/etc/miket/storage-credentials.env
Environment="RCLONE_B2_HARD_DELETE=true"
Environment="RCLONE_B2_ACCOUNT=${B2_APPLICATION_KEY_ID}"
Environment="RCLONE_B2_KEY=${B2_APPLICATION_KEY}"
ExecStart=/usr/bin/rclone sync /space :b2:miket-space-mirror \
    --fast-list \
    --transfers 16 \
    --track-renames \
    --log-file=/var/log/space-mirror.log \
    --log-level=INFO
User=root
```

**Trade-off:** Simpler but breaks pattern consistency.

---

## Best Practice Assessment

### ✅ Meets Best Practices

1. **Secrets Management:** Correctly uses AKV → `.env` → `EnvironmentFile` pattern
2. **Idempotency:** Rclone sync is idempotent
3. **Logging:** Centralized logging to `/var/log/space-mirror.log`
4. **Documentation:** Referenced in spec and script header
5. **Consistency:** Matches pattern used by other backup scripts

### ⚠️ Areas for Improvement

1. **Error Handling:** No explicit exit code checking
2. **Observability:** No metrics or notification hooks
3. **Validation:** No pre-flight checks (mounts, credentials, network)
4. **Monitoring:** No integration with monitoring stack

---

## Tool Choice Assessment

### Is There a Better Open-Source Alternative?

**Short Answer:** No. **rclone is already the industry standard** for cloud storage sync operations like this.

**Why rclone is the right choice:**
1. ✅ **Industry Standard:** Most widely-used CLI tool for cloud storage sync (supports 70+ backends)
2. ✅ **B2 Native Support:** First-class Backblaze B2 integration
3. ✅ **Battle-Tested:** Used by thousands of organizations for production backups
4. ✅ **Active Development:** Regular updates, security patches, feature additions
5. ✅ **CLI-First:** Perfect for automation and systemd integration
6. ✅ **No GUI Dependencies:** Headless operation, no X11/desktop required

**Alternatives Considered:**
- **Restic:** Different use case (versioned backups with deduplication). You're already using it for `/flux` backups, which is correct.
- **Duplicati:** GUI-based, Windows-focused, doesn't fit CLI/automation pattern
- **BorgBackup:** Similar to restic, but you're already standardized on restic
- **Kopia:** Modern alternative to restic, but again - different use case (versioned backups)
- **Resilio/Syncthing:** P2P sync tools, not designed for cloud backup

**The Real Question:** Should we eliminate the wrapper script?

**Answer:** The wrapper script is minimal but provides value:
- Environment variable normalization (AKV → rclone env vars)
- Credential validation (fail-fast if secrets missing)
- Consistent error handling pattern
- Future extensibility (metrics, notifications, pre-flight checks)

**Could we use rclone directly in systemd?** Yes, but you'd lose:
- Consistent pattern with `flux-backup.sh` and `flux-local-snap.sh`
- Easy place to add future enhancements
- Centralized error handling

**Verdict:** rclone is the right tool. The wrapper script is appropriate for your PHC patterns.

---

## Conclusion

**Verdict:** The custom script approach is **acceptable and recommended** for consistency with existing patterns, but should be enhanced with better error handling.

**Tool Choice:** ✅ **rclone is the correct choice** - it's the industry standard for cloud storage sync. No better alternatives exist that would eliminate the wrapper script need.

**Action Items:**
1. ✅ **IMMEDIATE:** Fix progress logging issue (already done - removed `--progress` flag)
2. ✅ **PRIORITY 1:** Add explicit exit code handling (already done)
3. ✅ **PRIORITY 2:** Simplify environment variable logic (already done)
4. 📋 **FUTURE:** Add observability hooks (metrics, notifications)

**Pattern Consistency:** Maintain custom script pattern to align with `flux-backup.sh` and `flux-local-snap.sh` unless there's a compelling reason to break consistency.

---

## Related Documentation

- **Specification:** `docs/product/DATA_LIFECYCLE_SPEC.md` §2.C
- **Secrets Management:** `docs/SECRETS.md`
- **Architecture Summary:** `docs/product/CHIEF_ARCHITECT_SUMMARY.md`
- **Implementation:** `ansible/roles/data-lifecycle/files/space-mirror.sh`

