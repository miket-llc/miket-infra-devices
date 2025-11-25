#!/bin/bash
# Copyright (c) 2025 MikeT LLC. All rights reserved.

# Reconcile multi-source transfers into /space/mike with backups and manifests

set -euo pipefail

DEFAULT_TARGET="/space/mike"
DEFAULT_RUN_ROOT="/space/inbox/reconciliation"
DEFAULT_RUN_ID="$(date +%Y%m%d-%H%M%S)"
CHECKSUM=false
DRY_RUN=false
CUSTOM_SOURCES=()

# Default source map: label|source_path|target_subdir
DEFAULT_SOURCES=(
  "count-zero-dev|/space/mike/dev|mike/dev"
  "count-zero-archives|/space/mike/archives|mike/archives"
  "count-zero-main-files|/space/mike/_MAIN_FILES|mike/_MAIN_FILES"
  "m365-main-files|/space/mike/_MAIN_FILES|mike/_MAIN_FILES"
  "count-zero-icloud|/space/devices/count-zero/icloud|devices/count-zero/icloud"
  "count-zero-downloads|/space/devices/count-zero/downloads|devices/count-zero/downloads"
  "wintermute-inbox|/space/inbox/wintermute-mdt_|inbox/wintermute-mdt_"
)

declare -A SOURCE_CLASSES=(
  [count-zero-dev]="primary"
  [count-zero-archives]="archive"
  [count-zero-main-files]="primary"
  [m365-main-files]="primary"
  [count-zero-icloud]="playground"
  [count-zero-downloads]="playground"
  [wintermute-inbox]="inbox"
)

declare -A DUPLICATE_POLICIES=(
  [primary]="One canonical copy under /space/mike; conflicts quarantined in run folder until curated."
  [archive]="Read-mostly; duplicates allowed only inside /space/mike/archives and backup manifests."
  [camera]="Raw evidence under /space/devices/<host>/<user>/camera; promote exactly one curated copy to /space/mike/assets/camera or /space/mike/art."
  [playground]="Ingest evidence only under /space/devices/<host>/<user>; promote to /space/mike after review, otherwise leave untouched."
  [inbox]="Staging only; must be promoted to canonical tree or archived, not duplicated."
  [unspecified]="Review before promotion; quarantine conflicts until a class is assigned."
)

print_help() {
  cat <<'USAGE'
Usage: reconcile-multi-source-transfers.sh [options]

Options:
  --target <path>      Target base directory (default: /space/mike)
  --run-root <path>    Reconciliation working root (default: /space/inbox/reconciliation)
  --run-id <id>        Reuse/define run identifier (default: current timestamp)
  --checksum           Generate SHA256 manifests during staging
  --source <label|src|dest>
                       Additional source mapping appended to defaults
                       Example: --source "extra-laptop|/mnt/usb|devices/extra-laptop"
  --dry-run            Execute rsync in dry-run mode
  --help               Show this message

The script stages all sources, builds manifests, generates a merge plan to copy one winner per path,
quarantines conflicts, and promotes the aggregate into the target directory without deletion.
USAGE
}

log() { printf '\033[0;36m[%s]\033[0m %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }
log_warn() { printf '\033[1;33m[%s] WARN\033[0m %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }
log_error() { printf '\033[0;31m[%s] ERROR\033[0m %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }

require_bin() {
  command -v "$1" >/dev/null 2>&1 || { log_error "Missing dependency: $1"; exit 1; }
}

parse_args() {
  TARGET="$DEFAULT_TARGET"
  RUN_ROOT="$DEFAULT_RUN_ROOT"
  RUN_ID="$DEFAULT_RUN_ID"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --target)
        TARGET="$2"; shift 2 ;;
      --run-root)
        RUN_ROOT="$2"; shift 2 ;;
      --run-id)
        RUN_ID="$2"; shift 2 ;;
      --checksum)
        CHECKSUM=true; shift ;;
      --source)
        CUSTOM_SOURCES+=("$2"); shift 2 ;;
      --dry-run)
        DRY_RUN=true; shift ;;
      --help)
        print_help; exit 0 ;;
      *)
        log_error "Unknown option: $1"; print_help; exit 1 ;;
    esac
  done
}

validate_target() {
  if [[ "$TARGET" != /space/* ]]; then
    log_error "Target must remain under /space to preserve SoR invariants: $TARGET"
    exit 1
  fi
}

init_paths() {
  RUN_DIR="${RUN_ROOT}/runs/${RUN_ID}"
  SOURCES_DIR="${RUN_DIR}/sources"
  AGGREGATE_DIR="${RUN_DIR}/aggregate"
  AGG_CONFLICTS_DIR="${RUN_DIR}/aggregate_conflicts"
  TARGET_CONFLICTS_DIR="${RUN_DIR}/conflicts/target"
  LOG_DIR="${RUN_DIR}/logs"
  MANIFEST_DIR="${RUN_DIR}/manifests"

  mkdir -p "$SOURCES_DIR" "$AGGREGATE_DIR" "$AGG_CONFLICTS_DIR" "$TARGET_CONFLICTS_DIR" "$LOG_DIR" "$MANIFEST_DIR"
}

select_sources() {
  if [[ ${#CUSTOM_SOURCES[@]} -gt 0 ]]; then
    SOURCES=("${DEFAULT_SOURCES[@]}" "${CUSTOM_SOURCES[@]}")
  else
    SOURCES=("${DEFAULT_SOURCES[@]}")
  fi
}

rsync_flags() {
  local flags=(-aHAX --info=stats2 --partial)
  [[ "$CHECKSUM" == true ]] && flags+=(--checksum)
  [[ "$DRY_RUN" == true ]] && flags+=(--dry-run)
  echo "${flags[@]}"
}

stage_source() {
  local label="$1"; local src="$2"
  local dest_dir="$SOURCES_DIR/$label"

  if [[ ! -e "$src" ]]; then
    log_warn "Skipping missing source: $src"
    return
  fi

  log "Staging source [$label]: $src -> $dest_dir"
  rsync $(rsync_flags) --progress "$src"/ "$dest_dir"/
}

build_manifest() {
  local label="$1"; local staged_dir="$2"
  local manifest="$MANIFEST_DIR/${label}-manifest.tsv"

  log "Building manifest for $label (checksum=${CHECKSUM})"
  python3 - <<'PY' "$staged_dir" "$manifest" "$CHECKSUM"
import hashlib, sys
from pathlib import Path

root = Path(sys.argv[1])
manifest = Path(sys.argv[2])
with_checksum = sys.argv[3].lower() == "true"

def file_checksum(path: Path) -> str:
    h = hashlib.sha256()
    with path.open('rb') as fh:
        for chunk in iter(lambda: fh.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()

manifest.parent.mkdir(parents=True, exist_ok=True)
with manifest.open('w', encoding='utf-8') as fh:
    for path in sorted(root.rglob('*')):
        if path.is_file():
            rel = path.relative_to(root)
            stat = path.stat()
            digest = file_checksum(path) if with_checksum else ""
            fh.write(f"{rel}\t{stat.st_size}\t{int(stat.st_mtime)}\t{digest}\n")
PY
}

write_plan_inputs() {
  PLAN_INPUT="$RUN_DIR/plan_inputs.tsv"
  : > "$PLAN_INPUT"
  for entry in "${SOURCES[@]}"; do
    IFS='|' read -r label src dest <<< "$entry"
    class="${SOURCE_CLASSES[$label]:-unspecified}"
    echo -e "${label}\t${SOURCES_DIR}/${label}\t${dest}\t${class}" >> "$PLAN_INPUT"
  done
}

generate_merge_plan() {
  PLAN_FILE="$LOG_DIR/merge-plan.tsv"
  python3 - <<'PY' "$PLAN_INPUT" "$MANIFEST_DIR" "$PLAN_FILE"
import sys, csv
from pathlib import Path

plan_input, manifest_dir, plan_file = map(Path, sys.argv[1:])

priority_order = [
    "primary",
    "archive",
    "camera",
    "playground",
    "inbox",
    "unspecified",
]
priority_index = {name: idx for idx, name in enumerate(priority_order)}

class Source:
    def __init__(self, label, staged, target, klass):
        self.label = label
        self.staged = staged
        self.target = target
        self.klass = klass

sources = []
for line in plan_input.read_text().splitlines():
    if not line.strip():
        continue
    label, staged, target, klass = line.split('\t')
    staged_path = Path(staged)
    manifest_path = manifest_dir / f"{label}-manifest.tsv"
    if not manifest_path.exists():
        continue
    entries = []
    for row in manifest_path.read_text().splitlines():
        rel, size, mtime, digest = row.split('\t')
        entries.append({
            "rel": rel,
            "size": int(size),
            "mtime": int(mtime),
            "digest": digest,
        })
    src = Source(label, staged_path, target, klass)
    src.entries = entries
    sources.append(src)

aggregate = {}
for src in sources:
    for entry in src.entries:
        agg_path = f"{src.target}/{entry['rel']}"
        aggregate.setdefault(agg_path, []).append({
            "label": src.label,
            "rel": entry['rel'],
            "size": entry['size'],
            "mtime": entry['mtime'],
            "digest": entry['digest'],
            "class": src.klass,
            "staged": str(src.staged),
        })

def winner(candidates):
    def key(item):
        return (
            priority_index.get(item['class'], len(priority_order)),
            -item['mtime'],
            -item['size'],
        )
    return sorted(candidates, key=key)[0]

lines = []
for agg_path, candidates in sorted(aggregate.items()):
    if len(candidates) == 1:
        c = candidates[0]
        lines.append(["copy", agg_path, c['label'], c['rel'], c['class'], "single-source"])
        continue

    digests = [c['digest'] for c in candidates if c['digest']]
    all_have_checksum = len(digests) == len(candidates) and len(digests) > 0
    unique_digests = set(digests)

    if all_have_checksum and len(unique_digests) == 1:
        champ = winner(candidates)
        lines.append(["copy", agg_path, champ['label'], champ['rel'], champ['class'], "duplicate (same checksum)"])
        for c in candidates:
            if c is champ:
                continue
            lines.append(["skip-duplicate", agg_path, c['label'], c['rel'], c['class'], "same checksum"])
        continue

    champ = winner(candidates)
    reason = "conflict (different content)" if all_have_checksum else "conflict (checksum missing)"
    lines.append(["copy", agg_path, champ['label'], champ['rel'], champ['class'], reason])
    for c in candidates:
        if c is champ:
            continue
        lines.append(["quarantine-conflict", agg_path, c['label'], c['rel'], c['class'], reason])

plan_file.parent.mkdir(parents=True, exist_ok=True)
with plan_file.open('w', newline='', encoding='utf-8') as fh:
    writer = csv.writer(fh, delimiter='\t')
    writer.writerow(["action", "aggregate_path", "source_label", "relative_path", "class", "reason"])
    writer.writerows(lines)
PY
}

execute_plan() {
  local plan="$LOG_DIR/merge-plan.tsv"
  local rsync_opts
  rsync_opts=$(rsync_flags)

  tail -n +2 "$plan" | while IFS=$'\t' read -r action agg_path label rel_path class reason; do
    src="$SOURCES_DIR/$label/$rel_path"
    case "$action" in
      copy)
        dest="$AGGREGATE_DIR/$agg_path"
        mkdir -p "$(dirname "$dest")"
        log "Copy -> aggregate: [$label] $rel_path => $agg_path ($reason)"
        rsync $rsync_opts "$src" "$dest"
        ;;
      skip-duplicate)
        log "Skip duplicate (checksum match): [$label] $rel_path"
        ;;
      quarantine-conflict)
        dest="$AGG_CONFLICTS_DIR/$label/$agg_path"
        mkdir -p "$(dirname "$dest")"
        log_warn "Conflict quarantine: [$label] $rel_path => $agg_path ($reason)"
        rsync $rsync_opts "$src" "$dest"
        ;;
      *)
        log_warn "Unknown plan action: $action for $agg_path"
        ;;
    esac
  done
}

promote_to_target() {
  log "Promoting aggregate to target: $TARGET"
  mkdir -p "$TARGET"
  rsync $(rsync_flags) --backup --backup-dir="$TARGET_CONFLICTS_DIR" --progress "$AGGREGATE_DIR"/ "$TARGET"/
}

write_summary() {
  local summary_file="$LOG_DIR/summary.txt"
  {
    echo "Run ID: $RUN_ID"
    echo "Timestamp: $(date --iso-8601=seconds)"
    echo "Target: $TARGET"
    echo "Checksum enabled: $CHECKSUM"
    echo "Dry run: $DRY_RUN"
    echo "Sources staged under: $SOURCES_DIR"
    echo "Aggregate path: $AGGREGATE_DIR"
    echo "Target conflict backups: $TARGET_CONFLICTS_DIR"
    echo "Aggregate conflict backups: $AGG_CONFLICTS_DIR"
    echo ""
    echo "Merge plan: $LOG_DIR/merge-plan.tsv"
    echo ""
    echo "Plan action counts:"
    if [[ -f "$LOG_DIR/merge-plan.tsv" ]]; then
      tail -n +2 "$LOG_DIR/merge-plan.tsv" | cut -f1 | sort | uniq -c | sed 's/^/  /'
    else
      echo "  (plan not generated)"
    fi
    echo ""
    echo "Source inventories:"
    for entry in "${SOURCES[@]}"; do
      IFS='|' read -r label path dest <<< "$entry"
      local staged="$SOURCES_DIR/$label"
      if [[ -d "$staged" ]]; then
        files=$(find "$staged" -type f | wc -l)
        size=$(du -sh "$staged" | cut -f1)
        echo "- $label ($path -> $dest): $files files, $size"
      else
        echo "- $label ($path -> $dest): NOT STAGED"
      fi
    done

    echo ""
    echo "Source classes and duplicate expectations:"
    for entry in "${SOURCES[@]}"; do
      IFS='|' read -r label path dest <<< "$entry"
      class="${SOURCE_CLASSES[$label]:-unspecified}"
      policy="${DUPLICATE_POLICIES[$class]:-${DUPLICATE_POLICIES[unspecified]}}"
      echo "- $label: class=$class → $policy"
    done

    echo ""
    echo "Allowed long-lived duplicates beyond the canonical tree:"
    echo "- /space/journal/** restic snapshots (immutable backups)"
    echo "- $TARGET_CONFLICTS_DIR (conflict backups for this run)"
    echo "- $AGG_CONFLICTS_DIR (aggregate-level backups for this run)"
    echo "- /space/archive/reconciliation/<run-id>/ (optional archived conflicts after triage)"
  } > "$summary_file"
  log "Summary written to $summary_file"
}

main() {
  parse_args "$@"
  require_bin rsync
  require_bin find
  require_bin python3

  validate_target

  select_sources
  init_paths

  for entry in "${SOURCES[@]}"; do
    IFS='|' read -r label src dest <<< "$entry"
    stage_source "$label" "$src"
    if [[ -d "$SOURCES_DIR/$label" ]]; then
      build_manifest "$label" "$SOURCES_DIR/$label"
    else
      log_warn "Skipped aggregation for $label (not staged)"
    fi
  done

  write_plan_inputs
  generate_merge_plan
  execute_plan

  promote_to_target
  [[ "$CHECKSUM" == true ]] && find "$AGGREGATE_DIR" -type f -print0 | sort -z | xargs -0 sha256sum > "$MANIFEST_DIR/aggregate-sha256.txt"
  write_summary

  log "Reconciliation complete. Review conflicts under $TARGET_CONFLICTS_DIR"
}

main "$@"
