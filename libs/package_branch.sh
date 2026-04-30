#!/usr/bin/env bash
# libs/package_branch.sh
#
# Package branch commits as numbered diff files.
#
# Produces unified output format:
#   <output-dir>/
#     uncommitted.diff      — git diff HEAD (uncommitted changes)
#     all-changes.diff      — git diff INIT_SHA (all changes since session init)
#     patches/
#       0001-<sha>.diff
#       0002-<sha>.diff
#       ...
#
# Each .diff file is a single-commit diff with index lines stripped,
# suitable for sequential git apply.
#
# Usage (library):
#   package_branch SANDBOX_DIR OUTPUT_DIR
#
# Usage (direct):
#   package_branch.sh [--session-summary=<text>] [--outdir=<path>]
#                     [--sandbox=<dir>] [--init-sha=<sha>]
#
# Arguments (library mode):
#   SANDBOX_DIR       — path to the git repository
#   OUTPUT_DIR        — full destination directory path
#
# Flags (direct mode):
#   --session-summary  Short snake_case label for the output directory.
#                      Default: "snapshot".
#   --outdir          Parent directory for output. Default: ~/workspace/output
#   --sandbox         Path to the git repository. Default: ~/sandbox.
#   --init-sha        Initial commit SHA. Default: read from SESSION_STATE.

_PB_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$_PB_SCRIPT_DIR/session.sh"
source "$_PB_SCRIPT_DIR/diff.sh"

# Only set strict mode when run directly, not when sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  set -euo pipefail
fi

# -------------------------
# package_commits
#
# Iterates commits since INIT_SHA, produces numbered .diff files with index
# lines stripped into PATCHES_DIR/, overwrites on each run.
# -------------------------
package_commits() {
  local SANDBOX_DIR="${1:-}"
  local INIT_SHA="${2:-}"
  local PATCHES_DIR="${3:-}"

  if [[ -z "$SANDBOX_DIR" || -z "$INIT_SHA" || -z "$PATCHES_DIR" ]]; then
    echo "package_commits: SANDBOX_DIR, INIT_SHA, and PATCHES_DIR are required" >&2
    return 1
  fi

  # Validate SANDBOX_DIR exists and is a git repository
  if [[ ! -d "$SANDBOX_DIR/.git" ]]; then
    echo "package_commits: SANDBOX_DIR is not a git repository: $SANDBOX_DIR" >&2
    return 1
  fi

  # Validate INIT_SHA is a valid commit
  if ! git -C "$SANDBOX_DIR" rev-parse --verify "${INIT_SHA}^{commit}" >/dev/null 2>&1; then
    echo "package_commits: INIT_SHA is not a valid commit: $INIT_SHA" >&2
    return 1
  fi

  # Remove existing diffs (overwrite on each run)
  rm -rf "$PATCHES_DIR"
  mkdir -p "$PATCHES_DIR"

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
      # First commit: diff from INIT_SHA to this commit
      PREVIOUS_SHA="$INIT_SHA"
    fi

    # Generate single-commit diff with index lines stripped
    local DIFF_FILE
    local PADDING
    PADDING=$(printf "%04d" "$INDEX")
    DIFF_FILE="${PATCHES_DIR}/${PADDING}-${COMMIT_SHA}.diff"

    git -C "$SANDBOX_DIR" diff "${PREVIOUS_SHA}..${COMMIT_SHA}" \
      | grep -v '^index ' \
      | sed 's/[[:space:]]*$//' \
      | sed -e '$a\' \
      > "$DIFF_FILE"

    PREVIOUS_SHA="$COMMIT_SHA"
    INDEX=$((INDEX + 1))
  done

  local DIFF_COUNT=$((INDEX - 1))
  echo "package_commits: generated ${DIFF_COUNT} diff(s) in ${PATCHES_DIR}" >&2
}

# -------------------------
# package_branch
#
# Dispatcher that produces the unified output format:
#   - uncommitted.diff  (uncommitted changes vs HEAD)
#   - all-changes.diff  (all changes since INIT_SHA)
#   - patches/          (numbered per-commit diffs)
#
# Reads INIT_SHA from SESSION_STATE. If SESSION_STATE is not available,
# the caller must ensure INIT_SHA is set or pass --init-sha in direct mode.
# -------------------------
package_branch() {
  local SANDBOX_DIR="${1:-}"
  local OUTPUT_DIR="${2:-}"

  if [[ -z "$SANDBOX_DIR" || -z "$OUTPUT_DIR" ]]; then
    echo "package_branch: SANDBOX_DIR and OUTPUT_DIR are required" >&2
    return 1
  fi

  # Read INIT_SHA from SESSION_STATE
  local INIT_SHA=""
  INIT_SHA=$(session_state_read "$SANDBOX_DIR" "init_sha")

  if [[ -z "$INIT_SHA" ]]; then
    echo "package_branch: init_sha not found in SESSION_STATE" >&2
    return 1
  fi

  mkdir -p "$OUTPUT_DIR"

  # Write uncommitted.diff (git diff HEAD)
  # Inline the logic to avoid a dependency on diff.sh when sourced
  local UNTRACKED_STAGED=()
  local UNTRACKED
  UNTRACKED=$(git -C "$SANDBOX_DIR" ls-files --others --exclude-standard 2>/dev/null || true)
  if [[ -n "$UNTRACKED" ]]; then
    while IFS= read -r F; do
      git -C "$SANDBOX_DIR" add -N -- "$F" 2>/dev/null && UNTRACKED_STAGED+=("$F")
    done <<< "$UNTRACKED"
  fi

  if git -C "$SANDBOX_DIR" diff --quiet HEAD 2>/dev/null; then
    > "$OUTPUT_DIR/uncommitted.diff"
  else
    git -C "$SANDBOX_DIR" diff HEAD \
      | grep -v '^index ' \
      | sed 's/[[:space:]]*$//' \
      | sed -e '$a\\' \
      > "$OUTPUT_DIR/uncommitted.diff"
  fi

  if [[ ${#UNTRACKED_STAGED[@]} -gt 0 ]]; then
    git -C "$SANDBOX_DIR" restore --staged -- "${UNTRACKED_STAGED[@]}" 2>/dev/null || true
  fi

  # Write all-changes.diff (git diff INIT_SHA)
  # Stage untracked files so they appear in the diff
  local ALL_UNTRACKED_STAGED=()
  local ALL_UNTRACKED
  ALL_UNTRACKED=$(git -C "$SANDBOX_DIR" ls-files --others --exclude-standard 2>/dev/null || true)
  if [[ -n "$ALL_UNTRACKED" ]]; then
    while IFS= read -r F; do
      git -C "$SANDBOX_DIR" add -N -- "$F" 2>/dev/null && ALL_UNTRACKED_STAGED+=("$F")
    done <<< "$ALL_UNTRACKED"
  fi

  if ! git -C "$SANDBOX_DIR" diff --quiet "${INIT_SHA}" 2>/dev/null; then
    git -C "$SANDBOX_DIR" diff --binary -M "${INIT_SHA}" > "$OUTPUT_DIR/all-changes.diff"
  fi

  if [[ ${#ALL_UNTRACKED_STAGED[@]} -gt 0 ]]; then
    git -C "$SANDBOX_DIR" restore --staged -- "${ALL_UNTRACKED_STAGED[@]}" 2>/dev/null || true
  fi

  # Write per-commit patches
  package_commits "$SANDBOX_DIR" "$INIT_SHA" "$OUTPUT_DIR/patches"

  # Write changed-files (accessibility copy)
  write_changed_files "$SANDBOX_DIR" "$INIT_SHA" "$OUTPUT_DIR"
}

# If run directly (not sourced), parse flags and execute
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  # Source diff.sh for write helpers in direct mode
  source "$_PB_SCRIPT_DIR/diff.sh"

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

  package_branch "$SANDBOX_DIR" "$OUTPUT_DIR"
fi
