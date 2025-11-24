#!/bin/bash
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

The script stages all sources, merges them into an aggregate tree with conflict backups,
and promotes the aggregate into the target directory without deletion.
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
  if [[ "$CHECKSUM" == true ]]; then
    log "Generating checksum manifest for $label"
    find "$dest_dir" -type f -print0 | sort -z | xargs -0 sha256sum > "$MANIFEST_DIR/${label}-sha256.txt"
  fi
}

merge_into_aggregate() {
  local label="$1"; local src_dir="$2"; local target_subdir="$3"
  local dest_dir="$AGGREGATE_DIR/$target_subdir"

  mkdir -p "$dest_dir"
  log "Merging [$label] into aggregate path: $target_subdir"
  rsync $(rsync_flags) --backup --backup-dir="$AGG_CONFLICTS_DIR/$label" --progress "$src_dir"/ "$dest_dir"/
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

  validate_target

  select_sources
  init_paths

  for entry in "${SOURCES[@]}"; do
    IFS='|' read -r label src dest <<< "$entry"
    stage_source "$label" "$src"
    if [[ -d "$SOURCES_DIR/$label" ]]; then
      merge_into_aggregate "$label" "$SOURCES_DIR/$label" "$dest"
    else
      log_warn "Skipped aggregation for $label (not staged)"
    fi
  done

  promote_to_target
  [[ "$CHECKSUM" == true ]] && find "$AGGREGATE_DIR" -type f -print0 | sort -z | xargs -0 sha256sum > "$MANIFEST_DIR/aggregate-sha256.txt"
  write_summary

  log "Reconciliation complete. Review conflicts under $TARGET_CONFLICTS_DIR"
}

main "$@"
