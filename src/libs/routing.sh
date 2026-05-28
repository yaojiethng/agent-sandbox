#!/usr/bin/env bash
# libs/routing.sh
#
# Path layout conventions and routing functions for agent-sandbox.
#
# Provides:
#   session_export_path     — construct export paths under CHANGES_DIR
#   output_export_path      — construct export paths under OUTPUT_DIR / INPUT_DIR
#   resolve_source_for_draft  — resolve a source directory for draft operations
#   resolve_diff_for_apply    — resolve a diff file for apply operations
#
# Session-diffs layout (new — introduced in A.2):
#   $CHANGES_DIR/session/<SESSION_TS>-<BRANCH>/     — exit exports
#     uncommitted.diff, all-changes.diff, EXPORT-TIME.txt, patches/, changed-files/
#   $CHANGES_DIR/autosave/<SESSION_TS>-<BRANCH>/    — autosave checkpoints
#     uncommitted.diff, all-changes.diff, EXPORT-TIME.txt, patches/, changed-files/
#
# Output layout (shared by package_branch and package_diff):
#   $OUTPUT_DIR/bundles/<TIMESTAMP>-<LABEL>[-<SESSION_TS>]/  — package_branch
#   $OUTPUT_DIR/diffs/<TIMESTAMP>-<LABEL>[-<SESSION_TS>]/    — package_diff
#
# Host-side input layout (symmetric, for host→container writes):
#   $INPUT_DIR/bundles/<TIMESTAMP>-<LABEL>[-<SESSION_TS>]/   — host writes
#   $INPUT_DIR/diffs/<TIMESTAMP>-<LABEL>[-<SESSION_TS>]/     — host writes
#
# Callers must provide SANDBOX_DIR before calling these functions. The routing
# functions derive CHANGES_DIR, INPUT_DIR, and OUTPUT_DIR from SANDBOX_DIR.
# They first try SESSION_STATE (written by sandbox-entrypoint after init), then
# fall back to dirs_resolve for host-side callers without a running container.

set -euo pipefail

_self_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$_self_dir/session_state.sh"
source "$_self_dir/dirs.sh"

# _resolve_path SANDBOX_DIR KEY
# Tries SESSION_STATE first, falls back to dirs_resolve.
# Sets CHANGES_DIR, INPUT_DIR, OUTPUT_DIR in the caller's scope.
_resolve_paths() {
  local SANDBOX_DIR="$1"
  local _d
  _d=$(session_state_read "$SANDBOX_DIR" "changes_dir" 2>/dev/null) && CHANGES_DIR="$_d"
  _d=$(session_state_read "$SANDBOX_DIR" "input_dir" 2>/dev/null) && INPUT_DIR="$_d"
  _d=$(session_state_read "$SANDBOX_DIR" "output_dir" 2>/dev/null) && OUTPUT_DIR="$_d"
  if [[ -z "${CHANGES_DIR:-}" || -z "${INPUT_DIR:-}" || -z "${OUTPUT_DIR:-}" ]]; then
    dirs_resolve "$SANDBOX_DIR"
  fi
}

# =============================================================================
# Channel directory resolution
# =============================================================================

# resolve_channel_base_dir CHANNEL
#
# Resolves a channel name to its base directory.
# Requires CHANGES_DIR and OUTPUT_DIR to be set (e.g. via _resolve_paths
# or dirs_resolve) before calling.
#
# Channel name    → Directory
#   session       → $CHANGES_DIR/session
#   autosave      → $CHANGES_DIR/autosave
#   diffs         → $OUTPUT_DIR/diffs
#   bundles       → $OUTPUT_DIR/bundles
#
# Returns 1 with error message to stderr for unknown channel names.
resolve_channel_base_dir() {
  local CHANNEL="$1"
  case "$CHANNEL" in
    session)  echo "${CHANGES_DIR}/session" ;;
    autosave) echo "${CHANGES_DIR}/autosave" ;;
    diffs)    echo "${OUTPUT_DIR}/diffs" ;;
    bundles)  echo "${OUTPUT_DIR}/bundles" ;;
    *)
      echo "Error: unknown channel: $CHANNEL" >&2
      echo "  Valid: session, autosave, diffs, bundles" >&2
      return 1
      ;;
  esac
}

# =============================================================================
# Session-export paths (used by entrypoint exit/autosave and CLI resolvers)
# =============================================================================

# session_export_path CHANGES_DIR SUBDIR SESSION_TS BRANCH
#
# Constructs the export output directory path for an auto-run (exit or autosave).
#
# Args:
#   CHANGES_DIR  — base changes directory (e.g. /home/agentuser/workspace/session-diffs)
#   SUBDIR       — "session" or "autosave"
#   SESSION_TS   — session timestamp (e.g. 20260408-120000)
#   BRANCH       — sanitized host branch name (e.g. main)
#
# Returns: absolute path to the export directory
#
# Example:
#   session_export_path "/home/agentuser/workspace/session-diffs" "session" "20260408-120000" "main"
#   → /home/agentuser/workspace/session-diffs/session/20260408-120000-main
session_export_path() {
  local CHANGES_DIR="$1"
  local SUBDIR="$2"
  local SESSION_TS="$3"
  local BRANCH="$4"

  if [[ -z "$CHANGES_DIR" || -z "$SUBDIR" || -z "$SESSION_TS" || -z "$BRANCH" ]]; then
    echo "session_export_path: CHANGES_DIR, SUBDIR, SESSION_TS, and BRANCH are required" >&2
    return 1
  fi

  echo "${CHANGES_DIR}/${SUBDIR}/${SESSION_TS}-${BRANCH}"
}

# =============================================================================
# Output export paths (used by package_branch.sh and package_diff.sh)
# =============================================================================

# output_export_path PARENT_DIR SUBDIR LABEL [SESSION_TS]
#
# Constructs a timestamped export path under a parent directory.
#
# Args:
#   PARENT_DIR   — base directory (OUTPUT_DIR or INPUT_DIR, resolved by caller)
#   SUBDIR       — "bundles" or "diffs"
#   LABEL        — descriptive label (e.g. "snapshot", or agent-provided summary)
#   SESSION_TS   — optional session timestamp suffix
#
# Returns: absolute path to the export directory (creates parent dirs)
#
# Examples:
#   output_export_path "/home/agentuser/workspace/output" "diffs" "snapshot" "20260408-120000"
#   → /home/agentuser/workspace/output/diffs/20260504-120000-snapshot-20260408-120000
#
#   output_export_path "/home/agentuser/workspace/output" "bundles" "my-feature"
#   → /home/agentuser/workspace/output/bundles/20260504-120000-my-feature
output_export_path() {
  local PARENT_DIR="$1"
  local SUBDIR="$2"
  local LABEL="$3"
  local SESSION_TS="${4:-}"

  if [[ -z "$PARENT_DIR" || -z "$SUBDIR" || -z "$LABEL" ]]; then
    echo "output_export_path: PARENT_DIR, SUBDIR, and LABEL are required" >&2
    return 1
  fi

  local EXPORT_TIME
  EXPORT_TIME=$(date -u +%Y%m%d-%H%M%S)

  local OUTDIR
  if [[ -n "$SESSION_TS" ]]; then
    OUTDIR="${PARENT_DIR}/${SUBDIR}/${EXPORT_TIME}-${LABEL}-${SESSION_TS}"
  else
    OUTDIR="${PARENT_DIR}/${SUBDIR}/${EXPORT_TIME}-${LABEL}"
  fi

  mkdir -p "$OUTDIR"
  echo "$OUTDIR"
}

# =============================================================================
# Draft source resolution
# =============================================================================

# resolve_source_for_draft SANDBOX_DIR CHANNEL [SESSION_ARG]
#
# Resolves the source directory and session name for draft operations.
# Prints tab-separated values: SOURCE_DIR<TAB>SESSION_NAME
#
# CHANNEL values:
#   session  — resolve from $CHANGES_DIR/session/ (default)
#   autosave — resolve from $CHANGES_DIR/autosave/
#   bundles  — resolve from $OUTPUT_DIR/bundles/
#
# SESSION_ARG behaviours:
#   non-empty — name-only, resolved under the channel's base directory
#   empty     — auto-resolve to the newest directory under the channel
#
# Returns 1 with error message to stderr on failure.
resolve_source_for_draft() {
  local SANDBOX_DIR="$1"
  local CHANNEL="${2:-session}"
  local SESSION_ARG="${3:-}"

  _resolve_paths "$SANDBOX_DIR"

  local BASE_DIR
  BASE_DIR=$(resolve_channel_base_dir "$CHANNEL") || return 1

  local RESOLVED_DIR=""
  local SESSION_NAME=""

  if [[ -n "$SESSION_ARG" ]]; then
    # Name-only resolution — reject anything that looks like an absolute path
    if [[ "$SESSION_ARG" == /* ]]; then
      echo "Error: --session is name-only; use --diff=<path> for explicit file paths" >&2
      return 1
    fi
    RESOLVED_DIR="${BASE_DIR}/${SESSION_ARG}"
    SESSION_NAME="$SESSION_ARG"
  else
    # Auto-resolve: newest directory under BASE_DIR
    if [[ ! -d "$BASE_DIR" ]]; then
      echo "Error: no session directories found under $BASE_DIR" >&2
      return 1
    fi
    RESOLVED_DIR=$(find "$BASE_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort | tail -n 1)
    if [[ -z "$RESOLVED_DIR" ]]; then
      echo "Error: no session directories found under $BASE_DIR" >&2
      return 1
    fi
    SESSION_NAME=$(basename "$RESOLVED_DIR")
  fi

  if [[ ! -d "$RESOLVED_DIR" ]]; then
    echo "Error: session directory not found: $RESOLVED_DIR" >&2
    return 1
  fi

  # Validate: must contain patches/ or uncommitted.diff
  if [[ ! -d "$RESOLVED_DIR/patches" ]] && [[ ! -f "$RESOLVED_DIR/uncommitted.diff" ]]; then
    echo "Error: session directory has no patches/ or uncommitted.diff: $RESOLVED_DIR" >&2
    return 1
  fi

  printf '%s\t%s' "$RESOLVED_DIR" "$SESSION_NAME"
}

# =============================================================================
# Apply diff resolution
# =============================================================================

# resolve_diff_for_apply SANDBOX_DIR CHANNEL [SESSION_ARG]
#
# Resolves a diff file path for apply operations.
# Prints the path to the resolved uncommitted.diff file.
#
# CHANNEL values:
#   diffs    — resolve from $OUTPUT_DIR/diffs/ (default)
#   autosave — resolve from $CHANGES_DIR/autosave/
#   session  — resolve from $CHANGES_DIR/session/
#
# SESSION_ARG behaviours:
#   non-empty — name-only, resolved under the channel's base directory
#   empty     — auto-resolve to the newest directory under the channel
#
# Returns 1 with error message to stderr on failure.
resolve_diff_for_apply() {
  local SANDBOX_DIR="$1"
  local CHANNEL="${2:-diffs}"
  local SESSION_ARG="${3:-}"

  _resolve_paths "$SANDBOX_DIR"

  local BASE_DIR
  BASE_DIR=$(resolve_channel_base_dir "$CHANNEL") || return 1

  local RESOLVED_DIR=""
  local SESSION_NAME=""

  if [[ -n "$SESSION_ARG" ]]; then
    # Name-only resolution — reject anything that looks like an absolute path
    if [[ "$SESSION_ARG" == /* ]]; then
      echo "Error: --session is name-only; use --diff=<path> for explicit file paths" >&2
      return 1
    fi
    RESOLVED_DIR="${BASE_DIR}/${SESSION_ARG}"
  else
    # Auto-resolve: newest directory under BASE_DIR
    if [[ ! -d "$BASE_DIR" ]]; then
      echo "Error: no session directories found under $BASE_DIR" >&2
      return 1
    fi
    RESOLVED_DIR=$(find "$BASE_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort | tail -n 1)
    if [[ -z "$RESOLVED_DIR" ]]; then
      echo "Error: no session directories found under $BASE_DIR" >&2
      return 1
    fi
  fi

  if [[ ! -d "$RESOLVED_DIR" ]]; then
    echo "Error: session directory not found: $RESOLVED_DIR" >&2
    return 1
  fi

  # Resolve uncommitted.diff
  local DIFF_FILE="${RESOLVED_DIR}/uncommitted.diff"
  if [[ ! -f "$DIFF_FILE" ]]; then
    echo "Error: uncommitted.diff not found in $RESOLVED_DIR" >&2
    return 1
  fi

  echo "$DIFF_FILE"
}
