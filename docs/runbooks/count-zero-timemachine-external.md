---
document_title: "count-zero Time Machine to External Drive (time2)"
author: "mdt"
last_updated: 2026-04-16
status: Active
related_initiatives:
  - initiatives/device-onboarding
linked_communications: []
---

# count-zero Time Machine to External Drive (`time2`)

**Replaces:** SMB-to-motoko Time Machine model documented in
`docs/runbooks/troubleshoot-timemachine-smb.md`. count-zero now backs up to a
**local external drive** (`time2`, 4TB APFS) instead of `motoko:/time` over SMB.

## Why this model

The previous model (TM → SMB sparsebundle on motoko) was fragile: USB device
drift on motoko, SMB session drops, and sparsebundle corruption all caused
backups to silently stop (last known good before this rework: 2025-12-10, four
months before recovery).

A directly-attached APFS drive removes the network and sparsebundle from the
hot path: TM writes natively, restores are point-and-click in Migration
Assistant, and failure modes are constrained to the physical drive.

## Hardware

- **Drive:** 4TB external (USB), APFS-formatted, single Backup-role volume
  named `time2`, mount point `/Volumes/time2`
- **APFS container:** `disk5` (physical store `disk4s2`)
- **Old SMB destination on motoko:** removed from TM; the `/time` share on
  motoko is no longer count-zero's backup target

## Critical exclusions

The following paths **must** stay excluded. Each one would cause data loss
risk on restore, redundant copies, or runaway disk usage.

| Path | Why excluded |
|---|---|
| `~/Nextcloud` | Server (`akira`) is the SoR with its own restic→B2 backup. Restoring an old TM copy of this directory would cause the desktop client to re-upload stale/deleted files, conflicting with live server state. |
| `~/Library/Mobile Documents` | iCloud Drive — Apple manages cloud copies. Local mirror in TM is redundant. **Requires `sudo tmutil addexclusion -p`** (path-based) — Apple blocks xattr-based exclusion for managed cloud paths. |
| `~/Library/CloudStorage` | OneDrive (and any other Files-on-Demand cloud provider) — same logic as iCloud. |
| `~/.cache`, `~/.npm`, `~/.cargo`, `~/.gradle`, `~/Library/Developer` | Rebuildable dev caches. Add additional cache dirs as new toolchains appear (e.g. `~/.pnpm-store`, `~/Library/pnpm`). |
| `/Volumes/motoko/*` (when present) | If the autofs migration is re-enabled (see `docs/runbooks/migrate-count-zero-to-autofs.md`), TM would attempt to back up `/space` and `/flux` over SMB. **Add this exclusion BEFORE re-enabling autofs.** |

The macOS-default exclusions (`/System`, `~/Library/Caches`, `~/.Trash`) are
left in place.

### Paths kept INCLUDED (deliberate)

- `~/Downloads` — kept for now; revisit if size becomes a problem.
- `/Applications` — kept; trades 71GB/snapshot for fast post-disaster rebuild.

## Quota policy

TM is capped at **3.5TB** via:

```
sudo defaults write /Library/Preferences/com.apple.TimeMachine MaxSize -int 3584000
```

Rationale: the drive is 4TB. The Dec 2025 snapshot (taken before this policy
existed) is ~2.6TB and contains everything that's now excluded. New snapshots
under this policy are small (initial ~50–250GB depending on `/Applications`,
deltas of single-digit GB). The 3.5TB cap forces TM to auto-thin the old fat
snapshot when new lean snapshots accumulate, while preserving ~500GB
breathing room on the drive.

## Apply the policy from scratch

```bash
# 1. Stop any in-progress backup
tmutil stopbackup

# 2. Add exclusions (xattr-based, no sudo needed for own files)
for p in \
  "$HOME/Nextcloud" \
  "$HOME/Library/CloudStorage" \
  "$HOME/.cache" \
  "$HOME/.npm" \
  "$HOME/.cargo" \
  "$HOME/.gradle" \
  "$HOME/Library/Developer"
do
  [ -e "$p" ] && tmutil addexclusion "$p"
done

# 3. iCloud requires path-based exclusion (sudo + -p flag)
sudo tmutil addexclusion -p "$HOME/Library/Mobile Documents"

# 4. Set 3.5TB quota
sudo defaults write /Library/Preferences/com.apple.TimeMachine MaxSize -int 3584000

# 5. Verify
for p in \
  "$HOME/Nextcloud" \
  "$HOME/Library/Mobile Documents" \
  "$HOME/Library/CloudStorage" \
  "$HOME/.cache"
do
  printf "%-50s : " "$p"
  tmutil isexcluded "$p"
done

# 6. Trigger fresh backup
tmutil startbackup
```

## Operational checks

```bash
# Is a backup running?
tmutil status

# When was the last successful backup?
tmutil latestbackup

# How much space is left on time2?
df -h /Volumes/time2

# What snapshots exist?
ls /Volumes/time2/

# Verify exclusions for a specific path
tmutil isexcluded ~/Nextcloud
```

## Battery / AC behavior

TM is currently configured to back up on battery (`RequiresACPower = 0`).
If you want to skip backups on battery:

```bash
sudo defaults write /Library/Preferences/com.apple.TimeMachine RequiresACPower -bool true
```

## When to revisit

- **Disk fills up despite quota** — TM's auto-thinning may not be aggressive
  enough. Manually delete the oldest snapshot:
  `sudo tmutil delete /Volumes/time2/<YYYY-MM-DD-HHMMSS>`
- **A new cloud-sync tool is installed** (Dropbox, Google Drive File Stream,
  Box Drive, etc.) — add its sync root to the exclusion list using the same
  reasoning as Nextcloud/iCloud/OneDrive.
- **Autofs is re-enabled** — add `/Volumes/motoko` to exclusions BEFORE the
  first autofs mount, otherwise TM will try to back up `/space` over SMB on
  the very next snapshot.
- **A new dev toolchain shows up with a large cache dir** — add it to the
  exclusion list above.

## Restoring from `time2`

For full-system restore, use Migration Assistant or macOS Recovery's
"Restore from Time Machine" — both auto-detect the APFS Backup volume.

For single-file restore, open the Time Machine UI (System Settings → Time
Machine → "Browse Time Machine Backups") or use `tmutil restore`.

**Do not restore `~/Nextcloud`, `~/Library/Mobile Documents`, or
`~/Library/CloudStorage` from TM.** These are excluded by policy; if they
appear in an old snapshot from before the policy existed (e.g. the Dec 2025
one), restoring them will conflict with the live cloud state. Re-sync from
the respective service instead.
