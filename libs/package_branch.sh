#!/usr/bin/env bash
# libs/package_branch.sh
#
# Package branch artefacts: per-commit diffs, uncommitted diff, all-changes
# diff, and changed-file copies — all in a single dispatcher call.
#
# Produces (under OUTPUT_DIR/):
#   patches/
#     0001-<sha>.diff       — per-commit diffs (index lines stripped)
#     0002-<sha>.diff
#     ...
#   uncommitted.diff        — uncommitted changes vs HEAD (with untracked)
#   all-changes.diff        — net delta INIT_SHA..HEAD (with untracked)
#   changed-files/          — working tree copies of all changed files
#     MANIFEST.txt
#
# Usage (library):
#   package_branch SANDBOX_DIR OUTPUT_DIR
#
# Usage (direct):
#   package_branch.sh --to=<dir> [--session-summary=<text>] [--baseline=<sha>]
#
# Arguments (library mode):
#   SANDBOX_DIR       — path to the git repository
#   OUTPUT_DIR        — full destination directory path
#   INIT_SHA_OVERRIDE — optional explicit baseline SHA
#
# Flags (direct mode):
#   --to=<dir>        Base parent directory (required). Script creates
#                     <to>/bundles/<ts>-<label>[-<ts>]/ subdirectory.
#   --session-summary Short snake_case label for the output directory.
#                     Default: "snapshot".
#   --baseline=<sha>  Explicit baseline SHA for commit history.

_PB_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$_PB_SCRIPT_DIR/session.sh"
source "$_PB_SCRIPT_DIR/diff.sh"
source "$_PB_SCRIPT_DIR/routing.sh"

# Only set strict mode when run directly, not when sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  set -euo pipefail
fi

# -------------------------
# package_commits
#
# Iterates commits since INIT_SHA, produces numbered .diff files with index
# lines stripped into OUTPUT_DIR/, overwrites on each run.
# Reads init_sha from SESSION_STATE.
# -------------------------
package_commits() {
  local SANDBOX_DIR="$1"
  local OUTPUT_DIR="$2"
  local INIT_SHA_OVERRIDE="${3:-}"

  if [[ -z "$SANDBOX_DIR" || -z "$OUTPUT_DIR" ]]; then
    echo "package_commits: SANDBOX_DIR and OUTPUT_DIR are required" >&2
    return 1
  fi

  local INIT_SHA
  if [[ -n "$INIT_SHA_OVERRIDE" ]]; then
    INIT_SHA="$INIT_SHA_OVERRIDE"
  else
    INIT_SHA=$(session_state_read "$SANDBOX_DIR" "init_sha")
    if [[ -z "$INIT_SHA" ]]; then
      echo "package_commits: init_sha not found in SESSION_STATE" >&2
      return 1
    fi
  fi

  # Validate SANDBOX_DIR exists and is a git repository
  if [[ ! -d "$SANDBOX_DIR/.git" ]]; then
    echo "package_commits: SANDBOX_DIR is not a git repository: $SANDBOX_DIR" >&2
    return 1
  fi

  # Remove existing diffs (overwrite on each run)
  rm -rf "$OUTPUT_DIR"
  mkdir -p "$OUTPUT_DIR"

  # Get list of commits since INIT_SHA
  local COMMITS
  COMMITS=$(git -C "$SANDBOX_DIR" rev-list "${INIT_SHA}..HEAD" --reverse)

  if [[ -z "$COMMITS" ]]; then
    echo "package_commits: no commits since INIT_SHA" >&2
    return 0
  fi

  local INDEX=1
  local PREVIOUS_SHA=""
  for COMMIT_SHA in $COMMITS; do
    if [[ -z "$PREVIOUS_SHA" ]]; then
      PREVIOUS_SHA="$INIT_SHA"
    fi

    local DIFF_FILE
    local PADDING
    PADDING=$(printf "%04d" "$INDEX")
    DIFF_FILE="${OUTPUT_DIR}/${PADDING}-${COMMIT_SHA}.diff"

    git -C "$SANDBOX_DIR" diff --binary "${PREVIOUS_SHA}..${COMMIT_SHA}" \
      | awk '/^index / { saved=$0; getline nl; if (nl ~ /^GIT binary patch/) print saved; print nl; next } 1' \
      | sed 's/[[:space:]]*$//' \
      | sed -e '$a\' \
      > "$DIFF_FILE"

    PREVIOUS_SHA="$COMMIT_SHA"
    INDEX=$((INDEX + 1))
  done

  local DIFF_COUNT=$((INDEX - 1))
  echo "package_commits: generated ${DIFF_COUNT} diff(s) in ${OUTPUT_DIR}" >&2
}

# -------------------------
# package_branch (dispatcher)
#
# Orchestrates all packaging output in a single call:
#   1. package_commits  — per-commit diffs under patches/
#   2. write_uncommitted_diff  — uncommitted.diff (git diff HEAD)
#   3. write_all_changes_diff  — all-changes.diff (git diff INIT_SHA)
#   4. write_changed_files     — changed-files/ with MANIFEST.txt
#
# Reads init_sha from SESSION_STATE, or uses an explicit override if provided.
# Overwrites OUTPUT_DIR on each run.
#
# Args:
#   SANDBOX_DIR       — path to the git repository
#   OUTPUT_DIR        — full destination directory (parent of patches/, etc.)
#   INIT_SHA_OVERRIDE — optional explicit baseline SHA; if omitted, reads
#                       init_sha from SESSION_STATE
# -------------------------
package_branch() {
  local SANDBOX_DIR="${1:-}"
  local OUTPUT_DIR="${2:-}"
  local INIT_SHA_OVERRIDE="${3:-}"

  if [[ -z "$SANDBOX_DIR" || -z "$OUTPUT_DIR" ]]; then
    echo "package_branch: SANDBOX_DIR and OUTPUT_DIR are required" >&2
    return 1
  fi

  local INIT_SHA
  if [[ -n "$INIT_SHA_OVERRIDE" ]]; then
    INIT_SHA="$INIT_SHA_OVERRIDE"
  else
    INIT_SHA=$(session_state_read "$SANDBOX_DIR" "init_sha")
    if [[ -z "$INIT_SHA" ]]; then
      echo "package_branch: init_sha not found in SESSION_STATE" >&2
      return 1
    fi
  fi

  # Validate SANDBOX_DIR exists and is a git repository
  if [[ ! -d "$SANDBOX_DIR/.git" ]]; then
    echo "package_branch: SANDBOX_DIR is not a git repository: $SANDBOX_DIR" >&2
    return 1
  fi

  # Remove and recreate OUTPUT_DIR
  rm -rf "$OUTPUT_DIR"
  mkdir -p "$OUTPUT_DIR"

  # 1. Per-commit diffs
  package_commits "$SANDBOX_DIR" "${OUTPUT_DIR}/patches" "$INIT_SHA"

  # 2. Uncommitted changes vs HEAD
  write_uncommitted_diff "$SANDBOX_DIR" "${OUTPUT_DIR}/uncommitted.diff"

  # 3. All changes since INIT_SHA
  write_all_changes_diff "$SANDBOX_DIR" "${OUTPUT_DIR}/all-changes.diff"

  # 4. Changed-file copies
  write_changed_files "$SANDBOX_DIR" "$INIT_SHA" "$OUTPUT_DIR"

  echo "package_branch: artefacts written to ${OUTPUT_DIR}" >&2
}

# If run directly (not sourced), parse flags and execute
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  TO_ARG=""
  SESSION_SUMMARY_ARG=""
  BASELINE_ARG=""

  for ARG in "$@"; do
    case "$ARG" in
      --session-summary=*) SESSION_SUMMARY_ARG="${ARG#--session-summary=}" ;;
      --to=*)              TO_ARG="${ARG#--to=}" ;;
      --baseline=*)        BASELINE_ARG="${ARG#--baseline=}" ;;
      --help)
        grep '^#' "$0" | grep -v '^#!/' | sed 's/^# \{0,1\}//'
        exit 0
        ;;
      *)
        echo "Unknown argument: $ARG" >&2
        echo "Usage: package_branch.sh --to=<dir> [--session-summary=<text>] [--baseline=<sha>]" >&2
        exit 1
        ;;
    esac
  done

  # --to is required
  if [[ -z "$TO_ARG" ]]; then
    echo "Error: --to is required. Specify a base output directory." >&2
    echo "  In container: --to=\$HOME/workspace/output" >&2
    echo "  On host: use 'agent-sandbox package-branch --sandbox=<path>' instead" >&2
    exit 1
  fi

  # Resolve SANDBOX_DIR from container default or git root
  if [[ -d "$HOME/sandbox" ]]; then
    SANDBOX_DIR="$HOME/sandbox"
  else
    echo "Error: could not find sandbox directory. Run inside the container." >&2
    exit 1
  fi

  # Resolve session summary
  SESSION_SUMMARY="snapshot"
  if [[ -n "$SESSION_SUMMARY_ARG" ]]; then
    SESSION_SUMMARY="$SESSION_SUMMARY_ARG"
  fi

  # Auto-resolve SESSION_TS from SESSION_STATE
  SESSION_TS=$(session_state_read "$SANDBOX_DIR" "session_ts")

  # Construct output directory via output_export_path
  OUTPUT_DIR=$(output_export_path "$TO_ARG" "bundles" "$SESSION_SUMMARY" "$SESSION_TS")

  package_branch "$SANDBOX_DIR" "$OUTPUT_DIR" "$BASELINE_ARG"
fi
