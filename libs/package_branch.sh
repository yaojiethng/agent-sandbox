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
# Usage:
#   package_branch SANDBOX_DIR INIT_SHA OUTPUT_DIR [SESSION_SUMMARY]
#
# Arguments:
#   SANDBOX_DIR       — path to the git repository
#   INIT_SHA          — initial commit SHA (from sandbox/.git/INIT_SHA)
#   OUTPUT_DIR        — full destination directory path (caller constructs)
#   SESSION_SUMMARY   — optional short description for logging only

# Only set strict mode when run directly, not when sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  set -euo pipefail
fi

# -------------------------
# package_branch
#
# Iterates commits since INIT_SHA, produces numbered .diff files with index
# lines stripped into SESSION_DIFFS_DIR/<branch-name>/, overwrites on each run.
# -------------------------
package_branch() {
  local SANDBOX_DIR="$1"
  local INIT_SHA="$2"
  local OUTPUT_DIR="$3"
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

# If run directly (not sourced), execute with positional arguments
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  package_branch "$@"
fi
