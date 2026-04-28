#!/usr/bin/env bash
# libs/package_branch.sh
#
# Package branch commits as numbered diff files.
#
# Produces:
#   <output-dir>/0001-<sha>.diff
#   <output-dir>/0002-<sha>.diff
#   ...
#
# Each .diff file is a single-commit diff with index lines stripped,
# suitable for sequential git apply.
#
# Usage (library):
#   package_branch SANDBOX_DIR INIT_SHA OUTPUT_DIR [SESSION_SUMMARY]
#
# Usage (direct):
#   package_branch.sh [--session-summary=<text>] [--outdir=<path>]
#                     [--sandbox=<dir>] [--init-sha=<sha>]
#
# Arguments (library mode):
#   SANDBOX_DIR       — path to the git repository
#   INIT_SHA          — initial commit SHA
#   OUTPUT_DIR        — full destination directory path
#   SESSION_SUMMARY   — optional short description for logging
#
# Flags (direct mode):
#   --session-summary  Short snake_case label for the output directory.
#                      Default: "snapshot".
#   --outdir          Parent directory for output. Default: ~/workspace/output
#   --sandbox         Path to the git repository. Default: ~/sandbox.
#   --init-sha        Initial commit SHA. Default: read from SESSION_STATE.

_PB_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$_PB_SCRIPT_DIR/session.sh"

# Only set strict mode when run directly, not when sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  set -euo pipefail
fi

# -------------------------
# package_branch
#
# Iterates commits since INIT_SHA, produces numbered .diff files with index
# lines stripped into OUTPUT_DIR/, overwrites on each run.
# -------------------------
package_branch() {
  local SANDBOX_DIR="${1:-}"
  local INIT_SHA="${2:-}"
  local OUTPUT_DIR="${3:-}"
  local SESSION_SUMMARY="${4:-}"

  if [[ -z "$SANDBOX_DIR" || -z "$INIT_SHA" || -z "$OUTPUT_DIR" ]]; then
    echo "package_branch: SANDBOX_DIR, INIT_SHA, and OUTPUT_DIR are required" >&2
    return 1
  fi

  # Validate SANDBOX_DIR exists and is a git repository
  if [[ ! -d "$SANDBOX_DIR/.git" ]]; then
    echo "package_branch: SANDBOX_DIR is not a git repository: $SANDBOX_DIR" >&2
    return 1
  fi

  # Validate INIT_SHA is a valid commit
  if ! git -C "$SANDBOX_DIR" rev-parse --verify "${INIT_SHA}^{commit}" >/dev/null 2>&1; then
    echo "package_branch: INIT_SHA is not a valid commit: $INIT_SHA" >&2
    return 1
  fi

  local BRANCH_DIFFS_DIR="$OUTPUT_DIR"

  # Remove existing diffs (overwrite on each run)
  rm -rf "$BRANCH_DIFFS_DIR"
  mkdir -p "$BRANCH_DIFFS_DIR"

  # Get list of commits since INIT_SHA
  local COMMITS
  COMMITS=$(git -C "$SANDBOX_DIR" rev-list "${INIT_SHA}..HEAD" --reverse)

  if [[ -z "$COMMITS" ]]; then
    echo "package_branch: no commits since INIT_SHA" >&2
    return 0
  fi

  local INDEX=1
  local PREVIOUS_SHA=""
  for COMMIT_SHA in $COMMITS; do
    if [[ -z "$PREVIOUS_SHA" ]]; then
      # First commit: diff from INIT_SHA to this commit
      PREVIOUS_SHA="$INIT_SHA"
    fi

    # Generate single-commit diff with index lines stripped
    local DIFF_FILE
    local PADDING
    PADDING=$(printf "%04d" "$INDEX")
    DIFF_FILE="${BRANCH_DIFFS_DIR}/${PADDING}-${COMMIT_SHA}.diff"

    git -C "$SANDBOX_DIR" diff "${PREVIOUS_SHA}..${COMMIT_SHA}" \
      | grep -v '^index ' \
      | sed 's/[[:space:]]*$//' \
      | sed -e '$a\' \
      > "$DIFF_FILE"

    PREVIOUS_SHA="$COMMIT_SHA"
    INDEX=$((INDEX + 1))
  done

  local DIFF_COUNT=$((INDEX - 1))
  echo "package_branch: generated ${DIFF_COUNT} diff(s) in ${BRANCH_DIFFS_DIR}" >&2
}

# If run directly (not sourced), parse flags and execute
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  SANDBOX_DIR=""
  INIT_SHA=""
  OUTDIR_ARG=""
  SESSION_SUMMARY_ARG=""

  for ARG in "$@"; do
    case "$ARG" in
      --session-summary=*) SESSION_SUMMARY_ARG="${ARG#--session-summary=}" ;;
      --outdir=*)          OUTDIR_ARG="${ARG#--outdir=}" ;;
      --sandbox=*)         SANDBOX_DIR="${ARG#--sandbox=}" ;;
      --init-sha=*)        INIT_SHA="${ARG#--init-sha=}" ;;
      --help)
        grep '^#' "$0" | grep -v '^#!/' | sed 's/^# \{0,1\}//'
        exit 0
        ;;
      *)
        echo "Unknown argument: $ARG" >&2
        echo "Usage: package_branch.sh [--session-summary=<text>] [--outdir=<path>] [--sandbox=<dir>] [--init-sha=<sha>]" >&2
        exit 1
        ;;
    esac
  done

  # Default sandbox dir
  if [[ -z "$SANDBOX_DIR" ]]; then
    if [[ -d "$HOME/sandbox" ]]; then
      SANDBOX_DIR="$HOME/sandbox"
    else
      echo "Error: could not find sandbox directory. Use --sandbox=<dir>" >&2
      exit 1
    fi
  fi

  # Auto-resolve INIT_SHA from SESSION_STATE if not provided
  if [[ -z "$INIT_SHA" ]]; then
    INIT_SHA=$(session_state_read "$SANDBOX_DIR" "init_sha")
    if [[ -z "$INIT_SHA" ]]; then
      echo "Error: could not resolve init_sha from SESSION_STATE. Use --init-sha=<sha>" >&2
      exit 1
    fi
  fi

  # Resolve session summary
  local SESSION_SUMMARY="snapshot"
  if [[ -n "$SESSION_SUMMARY_ARG" ]]; then
    SESSION_SUMMARY="$SESSION_SUMMARY_ARG"
  fi

  # Auto-resolve SESSION_TS from SESSION_STATE
  local SESSION_TS
  SESSION_TS=$(session_state_read "$SANDBOX_DIR" "session_ts")

  # Construct output directory
  local EXPORT_TIME
  EXPORT_TIME=$(date -u +%Y%m%d-%H%M%S)
  local OUTPUT_DIR
  if [[ -n "$OUTDIR_ARG" ]]; then
    OUTPUT_DIR="$OUTDIR_ARG"
  elif [[ -n "$SESSION_TS" ]]; then
    OUTPUT_DIR="$HOME/workspace/output/bundles/${EXPORT_TIME}-${SESSION_SUMMARY}-${SESSION_TS}"
  else
    OUTPUT_DIR="$HOME/workspace/output/bundles/${EXPORT_TIME}-${SESSION_SUMMARY}"
  fi

  package_branch "$SANDBOX_DIR" "$INIT_SHA" "$OUTPUT_DIR" "$SESSION_SUMMARY"
fi
