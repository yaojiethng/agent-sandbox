#!/usr/bin/env bash
# libs/package_diff.sh
#
# Package changed files and a unified diff into an output directory.
#
# Produces (under <to>/diffs/<EXPORT_TIME>-<LABEL>[-<SESSION_TS>]/):
#   uncommitted.diff           — unified diff against HEAD (default)
#   all-changes.diff           — unified diff against baseline (--all or --baseline)
#   changed-files/             — full copies of every changed file
#     MANIFEST.txt
#
# Usage (direct):
#   package_diff.sh --to=<dir> [--session-summary=<text>] [--all|--baseline=<sha>]
#
#   --to=<dir>               Base parent directory (required). Script creates
#                             <to>/diffs/<ts>-<label>[-<ts>]/ subdirectory.
#   --session-summary=<text>  Short snake_case label for the output folder.
#                             Default: "snapshot".
#   --all                     Diff against session baseline (reads SESSION_STATE).
#                             Produces all-changes.diff instead of uncommitted.diff.
#   --baseline=<sha>          Diff against an explicit SHA. Produces all-changes.diff.
#
# The --all and --baseline flags are mutually exclusive.
# If neither is given, the script packages only uncommitted changes (git diff HEAD).
#
# Inside the container, run directly with --to=$HOME/workspace/output:
#   bash /opt/sandbox/lib/package_diff.sh --to=$HOME/workspace/output --session-summary=<text>
#
# On the host, use agent-sandbox package-diff which resolves paths from .env.

_PD_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$_PD_SCRIPT_DIR/session.sh"
source "$_PD_SCRIPT_DIR/diff.sh"
source "$_PD_SCRIPT_DIR/routing.sh"

# Only set strict mode and run setup when run directly, not when sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  set -euo pipefail

  # -------------------------
  # Locate repo root
  # -------------------------
  if ! REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null); then
    echo "Error: not inside a git repository." >&2
    exit 1
  fi

  # -------------------------
  # Flag parsing (direct mode only)
  # -------------------------
  TO_ARG=""
  SESSION_SUMMARY_ARG=""
  ALL_FLAG=false
  BASELINE_ARG=""

  for ARG in "$@"; do
    case "$ARG" in
      --to=*)              TO_ARG="${ARG#--to=}" ;;
      --session-summary=*) SESSION_SUMMARY_ARG="${ARG#--session-summary=}" ;;
      --all)               ALL_FLAG=true ;;
      --baseline=*)        BASELINE_ARG="${ARG#--baseline=}" ;;
      --help)
        grep '^#' "$0" | grep -v '^#!/' | sed 's/^# \{0,1\}//'
        exit 0
        ;;
      *)
        echo "Unknown argument: $ARG" >&2
        echo "Usage: package_diff.sh --to=<dir> [--session-summary=<text>] [--all|--baseline=<sha>]" >&2
        exit 1
        ;;
    esac
  done

  # --to is required
  if [[ -z "$TO_ARG" ]]; then
    echo "Error: --to is required. Specify a base output directory." >&2
    echo "  In container: --to=\$HOME/workspace/output" >&2
    echo "  On host: use 'agent-sandbox package-diff --sandbox=<path>' instead" >&2
    exit 1
  fi

  # --all and --baseline are mutually exclusive
  if [[ "$ALL_FLAG" == true && -n "$BASELINE_ARG" ]]; then
    echo "Error: --all and --baseline are mutually exclusive." >&2
    exit 1
  fi

  # Resolve session summary
  SESSION_SUMMARY="snapshot"
  if [[ -n "$SESSION_SUMMARY_ARG" ]]; then
    SESSION_SUMMARY="$SESSION_SUMMARY_ARG"
  fi

  # Resolve session timestamp (may be empty — fine, output_export_path handles it)
  SESSION_TS=$(session_state_read "$REPO_ROOT" "session_ts" 2>/dev/null || true)

  # -------------------------
  # Create output directory via output_export_path
  # -------------------------
  OUTDIR=$(output_export_path "$TO_ARG" "diffs" "$SESSION_SUMMARY" "$SESSION_TS")

  # -------------------------
  # Check for changes
  # -------------------------
  UNTRACKED=$(git -C "$REPO_ROOT" ls-files --others --exclude-standard 2>/dev/null || true)

  if git -C "$REPO_ROOT" diff --quiet HEAD 2>/dev/null && [[ -z "$UNTRACKED" ]] && git -C "$REPO_ROOT" diff --cached --quiet 2>/dev/null; then
    # For --all and --baseline, also check if there are committed changes since baseline
    if [[ -z "$ALL_FLAG" && -z "$BASELINE_ARG" ]]; then
      echo "Nothing to package — no changes found against HEAD." >&2
      rmdir "$OUTDIR" 2>/dev/null || true
      exit 0
    fi
  fi

  # -------------------------
  # Generate diff
  # -------------------------
  if [[ -n "$BASELINE_ARG" ]]; then
    # Diff against explicit baseline SHA
    write_all_changes_diff "$REPO_ROOT" "$OUTDIR/all-changes.diff" "$BASELINE_ARG"
    DIFF_FILE="all-changes.diff"
  elif [[ "$ALL_FLAG" == true ]]; then
    # Diff against session baseline (reads SESSION_STATE)
    write_all_changes_diff "$REPO_ROOT" "$OUTDIR/all-changes.diff"
    DIFF_FILE="all-changes.diff"
  else
    # Default: uncommitted changes vs HEAD
    write_uncommitted_diff "$REPO_ROOT" "$OUTDIR/uncommitted.diff"
    DIFF_FILE="uncommitted.diff"
  fi

  DIFF_LINES=$(wc -l < "$OUTDIR/$DIFF_FILE" | tr -d ' ')

  # -------------------------
  # Copy changed files
  # -------------------------
  local SINCE_SHA="HEAD"
  if [[ -n "$BASELINE_ARG" ]]; then
    SINCE_SHA="$BASELINE_ARG"
  elif [[ "$ALL_FLAG" == true ]]; then
    SINCE_SHA=$(session_state_read "$REPO_ROOT" "init_sha" 2>/dev/null || echo "HEAD")
  fi
  write_changed_files "$REPO_ROOT" "$SINCE_SHA" "$OUTDIR"

  # -------------------------
  # Summary
  # -------------------------
  echo "Output directory: $OUTDIR"
  echo "Diff file:        $DIFF_FILE (${DIFF_LINES} lines)"

  CHANGED_FILES_DIR="$OUTDIR/changed-files"
  if [[ -d "$CHANGED_FILES_DIR" ]]; then
    CHANGED_FILE_COUNT=$(find "$CHANGED_FILES_DIR" -type f ! -name MANIFEST.txt | wc -l | tr -d ' ')
    echo "Changed files:    ${CHANGED_FILE_COUNT}"
  fi

  echo ""
  echo "Contents:"
  echo "  $OUTDIR/$DIFF_FILE"
  if [[ -d "$CHANGED_FILES_DIR" ]]; then
    echo "  $OUTDIR/changed-files/  (${CHANGED_FILE_COUNT} files)"
  fi
fi
