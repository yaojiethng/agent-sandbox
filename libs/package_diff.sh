#!/usr/bin/env bash
# libs/package_diff.sh
#
# Package changed files and a unified diff into an output directory.
#
# Produces (under OUTDIR/):
#   uncommitted.diff          — unified diff against HEAD (index lines stripped)
#   changed-files/            — full copies of every changed file, preserving
#                               directory structure relative to repo root
#     MANIFEST.txt
#
# Usage (direct):
#   package_diff.sh [--session-summary=<text>] [--outdir=<path>] [--session-ts=<ts>]
#
#   --session-summary=<text>  Short snake_case label for the output folder name.
#                             Default: "snapshot".
#   --outdir=<path>           Parent directory for output. Default: ~/workspace/output
#   --session-ts=<ts>         Session timestamp for the output folder name suffix.
#                             Default: read from SESSION_STATE.
#
# Alias registration (host only — done by agent-sandbox onboard):
#   git config --local alias.package-diff \
#     '!bash $(git rev-parse --show-toplevel)/../agent-sandbox/libs/package_diff.sh'
#
# Inside the container, invoke directly — the alias is not registered in the
# sandbox .git/config:
#   bash /opt/sandbox/lib/package_diff.sh [--session-summary=<text>]

_PD_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$_PD_SCRIPT_DIR/session.sh"
source "$_PD_SCRIPT_DIR/diff.sh"
source "$_PD_SCRIPT_DIR/routing.sh"

# Only set strict mode when run directly, not when sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  set -euo pipefail
fi

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
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  SESSION_SUMMARY_ARG=""
  OUTDIR_ARG=""
  SESSION_TS_ARG=""

  for ARG in "$@"; do
    case "$ARG" in
      --session-summary=*) SESSION_SUMMARY_ARG="${ARG#--session-summary=}" ;;
      --outdir=*)          OUTDIR_ARG="${ARG#--outdir=}" ;;
      --session-ts=*)      SESSION_TS_ARG="${ARG#--session-ts=}" ;;
      --help)
        grep '^#' "$0" | grep -v '^#!/' | sed 's/^# \{0,1\}//'
        exit 0
        ;;
      *)
        echo "Unknown argument: $ARG" >&2
        echo "Usage: package_diff.sh [--session-summary=<text>] [--outdir=<path>] [--session-ts=<ts>]" >&2
        exit 1
        ;;
    esac
  done

  # -------------------------
  # Detect container context
  # -------------------------
  IN_CONTAINER=0
  [[ -d "$HOME/workspace/output" ]] && IN_CONTAINER=1

  # -------------------------
  # Resolve output parent directory
  # -------------------------
  if [[ -n "$OUTDIR_ARG" ]]; then
    PARENT_DIR="$OUTDIR_ARG"
  elif [[ "$IN_CONTAINER" -eq 1 ]]; then
    PARENT_DIR="$HOME/workspace/output"
  else
    PARENT_DIR="$REPO_ROOT/.package-diff-output"
  fi
  mkdir -p "$PARENT_DIR"

  # -------------------------
  # Resolve session summary
  # -------------------------
  SESSION_SUMMARY="snapshot"
  if [[ -n "$SESSION_SUMMARY_ARG" ]]; then
    SESSION_SUMMARY="$SESSION_SUMMARY_ARG"
  fi

  # -------------------------
  # Resolve session timestamp
  # -------------------------
  if [[ -n "$SESSION_TS_ARG" ]]; then
    SESSION_TS="$SESSION_TS_ARG"
  else
    SESSION_TS=$(session_state_read "$REPO_ROOT" "session_ts")
  fi

  # -------------------------
  # Create output directory via output_export_path
  # -------------------------
  OUTDIR=$(output_export_path "$PARENT_DIR" "diffs" "$SESSION_SUMMARY" "$SESSION_TS")

  # -------------------------
  # Check for changes
  # -------------------------
  UNTRACKED=$(git -C "$REPO_ROOT" ls-files --others --exclude-standard 2>/dev/null || true)

  if git -C "$REPO_ROOT" diff --quiet HEAD 2>/dev/null && [[ -z "$UNTRACKED" ]] && git -C "$REPO_ROOT" diff --cached --quiet 2>/dev/null; then
    echo "Nothing to package — no changes found against HEAD." >&2
    rmdir "$OUTDIR" 2>/dev/null || true
    exit 0
  fi

  # -------------------------
  # Generate uncommitted.diff
  # -------------------------
  write_uncommitted_diff "$REPO_ROOT" "$OUTDIR/uncommitted.diff"

  DIFF_LINES=$(wc -l < "$OUTDIR/uncommitted.diff" | tr -d ' ')

  # -------------------------
  # Copy changed files
  # -------------------------
  write_changed_files "$REPO_ROOT" "HEAD" "$OUTDIR"

  # -------------------------
  # Summary
  # -------------------------
  echo "Output directory: $OUTDIR"
  echo "Diff size:        ${DIFF_LINES} lines"

  CHANGED_FILES_DIR="$OUTDIR/changed-files"
  if [[ -d "$CHANGED_FILES_DIR" ]]; then
    CHANGED_FILE_COUNT=$(find "$CHANGED_FILES_DIR" -type f ! -name MANIFEST.txt | wc -l | tr -d ' ')
    echo "Changed files:    ${CHANGED_FILE_COUNT}"
  fi

  echo ""
  echo "Contents:"
  echo "  $OUTDIR/uncommitted.diff"
  if [[ -d "$CHANGED_FILES_DIR" ]]; then
    echo "  $OUTDIR/changed-files/  (${CHANGED_FILE_COUNT} files)"
  fi
fi
