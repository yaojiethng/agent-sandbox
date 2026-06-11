#!/usr/bin/env bash
# libs/package_branch.sh
#
# Package branch artefacts: per-commit diffs, uncommitted diff, all-changes
# diff, and changed-file copies — all in a single dispatcher call.
#
# Produces (under OUTPUT_DIR/):
#   patches/
#     0001-<sha>[-<subject>].diff  — per-commit diffs (index lines stripped)
#     0001-<sha>[-<subject>].msg   — full commit message for each diff
#     0002-<sha>[-<subject>].diff
#     0002-<sha>[-<subject>].msg
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

_self_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$_self_dir/session_state.sh"
source "$_self_dir/diff.sh"
source "$_self_dir/routing.sh"

# =============================================================================
# usage — print help text
# =============================================================================

usage() {
  cat <<EOF
Usage: agent-sandbox package-branch --sandbox=<path> [options]

Packages branch artefacts: per-commit diffs, uncommitted diff, all-changes diff.

Required:
  --sandbox=<path>    Path to the sandbox directory

Options:
  --to=<dir>              Output directory (default: auto-resolved from sandbox)
  --session-summary=<txt> Required snake_case label for the bundle directory
  --baseline=<sha>        Override baseline SHA (default: read from SESSION_STATE)
  --no-renames            Use git diff --no-renames (avoid rename operations in diffs)
EOF
}

# Only set strict mode when run directly, not when sourced
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
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
  local NO_RENAMES="${4:-false}"

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
    local COMMIT_SUBJECT
    COMMIT_SUBJECT=$(git -C "$SANDBOX_DIR" log --format="%s" -1 "$COMMIT_SHA" 2>/dev/null | sed 's/[^a-zA-Z0-9._-]/_/g' | head -c 60) || COMMIT_SUBJECT=""
    if [[ -n "$COMMIT_SUBJECT" ]]; then
      DIFF_FILE="${OUTPUT_DIR}/${PADDING}-${COMMIT_SHA}-${COMMIT_SUBJECT}.diff"
    else
      DIFF_FILE="${OUTPUT_DIR}/${PADDING}-${COMMIT_SHA}.diff"
    fi

    local GIT_DIFF_OPTS="--binary"
    if [[ "$NO_RENAMES" == "true" ]]; then
      GIT_DIFF_OPTS="--binary --no-renames"
    fi
    git -C "$SANDBOX_DIR" diff $GIT_DIFF_OPTS "${PREVIOUS_SHA}..${COMMIT_SHA}" \
      | strip_index_lines \
      | sed 's/[[:space:]]*$//' \
      | sed -e '$a\' \
      > "$DIFF_FILE"

    # Write sibling .msg file with full commit message
    local MSG_FILE="${DIFF_FILE%.diff}.msg"
    git -C "$SANDBOX_DIR" log --format="%B" -1 "$COMMIT_SHA" > "$MSG_FILE" 2>/dev/null || true

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
#   NO_RENAMES        — if true, use git diff --no-renames to produce diffs
#                       without rename operations (avoids rename-target-already-exists
#                       conflicts during apply at the cost of larger diffs)
# -------------------------
# -------------------------
# _package_preflight_check
#
# Verifies that the working tree has no uncommitted modifications to files
# that appear in the committed diff between INIT_SHA and HEAD. Such
# modifications would cause the committed patches' old-state context to
# diverge from the baseline, making them unappliable.
#
# Also warns when a file in the committed diff was independently modified
# between INIT_SHA and the parent commit that introduced the file's change
# (intermediate committed reorders that cancel out).
#
# This check catches the class of divergence documented in:
#   devlog/discussions/20260526-study-unappliable_patch_structural_cleanup.md
#
# Skips check when PACKAGE_BYPASS_PREFLIGHT=true is set.
# Returns 0 always — warnings only, never blocks packaging.
# -------------------------
_package_preflight_check() {
  local SANDBOX_DIR="$1"
  local INIT_SHA="$2"

  if [[ "${PACKAGE_BYPASS_PREFLIGHT:-false}" == "true" ]]; then
    return 0
  fi

  local FLAGGED=0
  local CHANGED_FILES
  CHANGED_FILES=$(git -C "$SANDBOX_DIR" diff --name-only "${INIT_SHA}..HEAD" 2>/dev/null || true)

  if [[ -z "$CHANGED_FILES" ]]; then
    return 0
  fi

  for f in $CHANGED_FILES; do
    # Skip deleted files
    if ! git -C "$SANDBOX_DIR" cat-file -e "HEAD:$f" 2>/dev/null; then
      continue
    fi

    # Check for uncommitted modifications (working tree differs from HEAD)
    if ! git -C "$SANDBOX_DIR" diff --quiet -- "$f" 2>/dev/null; then
      echo "Warning: '$f' has uncommitted modifications in the working tree." >&2
      echo "  The committed patch for this file was generated against HEAD," >&2
      echo "  but the working tree has additional changes. The committed patch" >&2
      echo "  may not apply cleanly to the baseline." >&2
      FLAGGED=1
    fi

    # Check for intermediate committed reorders: compare the file's blob
    # at INIT_SHA vs HEAD. If they match but the file appears in the diff
    # list, the file was modified and reverted during the session — the
    # patch may reference a state that never existed at INIT_SHA.
    if git -C "$SANDBOX_DIR" cat-file -e "${INIT_SHA}:$f" 2>/dev/null; then
      if git -C "$SANDBOX_DIR" diff --quiet "$INIT_SHA" -- "$f" 2>/dev/null; then
        echo "Warning: '$f' in the committed diff has identical content at" >&2
        echo "  baseline and HEAD (intermediate modifications cancelled out)." >&2
        echo "  The patch context may not match the baseline. Review before applying." >&2
        FLAGGED=1
      fi
    fi
  done

  if [[ "$FLAGGED" -eq 1 ]]; then
    echo "Warning: pre-flight check flagged potential patch divergence." >&2
    echo "  Set PACKAGE_BYPASS_PREFLIGHT=true to skip this check." >&2
  fi

  return 0
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
  local NO_RENAMES="${4:-false}"

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

  # Pre-flight: check for potential patch divergence from baseline
  _package_preflight_check "$SANDBOX_DIR" "$INIT_SHA"

  # Remove and recreate OUTPUT_DIR
  rm -rf "$OUTPUT_DIR"
  mkdir -p "$OUTPUT_DIR"

  # 1. Per-commit diffs
  package_commits "$SANDBOX_DIR" "${OUTPUT_DIR}/patches" "$INIT_SHA" "$NO_RENAMES"

  # 2. Uncommitted changes vs HEAD
  write_uncommitted_diff "$SANDBOX_DIR" "${OUTPUT_DIR}/uncommitted.diff"

  # 3. All changes since INIT_SHA
  write_all_changes_diff "$SANDBOX_DIR" "${OUTPUT_DIR}/all-changes.diff"

  # 4. Changed-file copies
  write_changed_files "$SANDBOX_DIR" "$INIT_SHA" "$OUTPUT_DIR"

  echo "package_branch: artefacts written to ${OUTPUT_DIR}" >&2

  local bundle_name
  bundle_name=$(basename "$OUTPUT_DIR")
  echo "To draft this bundle on host, run:" >&2
  echo "  make draft FROM=bundles SESSION=${bundle_name} BRANCH_SUMMARY=<slug>" >&2
}

# If run directly (not sourced), parse flags and execute
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  TO_ARG=""
  SESSION_SUMMARY_ARG=""
  BASELINE_ARG=""
  NO_RENAMES_ARG=false

  for ARG in "$@"; do
    case "$ARG" in
      --help|-h) usage; exit 0 ;;
      --session-summary=*) SESSION_SUMMARY_ARG="${ARG#--session-summary=}" ;;
      --to=*)              TO_ARG="${ARG#--to=}" ;;
      --baseline=*)        BASELINE_ARG="${ARG#--baseline=}" ;;
      --no-renames)        NO_RENAMES_ARG=true ;;
      *)
        echo "Unknown argument: $ARG" >&2
        usage >&2
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

  # --session-summary is required (same class as --to)
  if [[ -z "$SESSION_SUMMARY_ARG" ]]; then
    echo "Error: --session-summary is required. Provide a concise snake_case label." >&2
    echo "" >&2
    echo "  Good: --session-summary=fix_provisioning_metadata_agnostic" >&2
    echo "  Good: --session-summary=add_format_patch_support" >&2
    echo "  Bad:  --session-summary=changes" >&2
    echo "  Bad:  --session-summary=snapshot" >&2
    echo "  Bad:  --session-summary=misc" >&2
    echo "" >&2
    echo "Usage: package_branch.sh --to=<dir> --session-summary=<text> [--baseline=<sha>]" >&2
    echo "" >&2
    echo "  --to=<dir>           Required. Base output directory." >&2
    echo "  --session-summary    Required. Snake_case label for the bundle directory." >&2
    echo "  --baseline=<sha>     Optional. Override baseline SHA (default: read from SESSION_STATE)." >&2
    exit 1
  fi
  SESSION_SUMMARY="$SESSION_SUMMARY_ARG"

  # Auto-resolve RUN_ID from SESSION_STATE
  RUN_ID=$(session_state_read "$SANDBOX_DIR" "run_id" 2>/dev/null || true)

  # Construct output directory via output_export_path
  OUTPUT_DIR=$(output_export_path "$TO_ARG" "bundles" "$SESSION_SUMMARY" "$RUN_ID")

  package_branch "$SANDBOX_DIR" "$OUTPUT_DIR" "$BASELINE_ARG" "$NO_RENAMES_ARG"
fi
