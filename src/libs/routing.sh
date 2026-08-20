#!/usr/bin/env bash
# libs/routing.sh
#
# Path layout conventions and routing functions for agent-sandbox.
#
# Provides:
#   export_path              — unified export path constructor (replaces session_export_path
#                              and output_export_path)
#   resolve_source_for_draft  — resolve a source directory for draft operations
#   resolve_diff_for_apply    — resolve a diff file for apply operations
#
# Export path convention:
#   <PARENT_DIR>/<SUBDIR>/<EXPORT_TIME>-<SESSION_ID>/
#   <PARENT_DIR>/<SUBDIR>/<EXPORT_TIME>-<LABEL>-<SESSION_ID>/
#
#   EXPORT_TIME = date -u at invocation time
#   SESSION_ID   = mandatory 6-char session hash
#   LABEL        = optional human-readable descriptor
#
# Layout:
#   $CHANGES_DIR/session/<EXPORT_TIME>-<SESSION_ID>/     — exit exports
#   $CHANGES_DIR/autosave/<SESSION_ID>/                  — autosave (single, overwritten)
#   $OUTPUT_DIR/bundles/<EXPORT_TIME>-<SESSION_ID>/      — package_branch
#   $OUTPUT_DIR/bundles/<EXPORT_TIME>-<LABEL>-<SESSION_ID>/  — package_branch with label
#
# Callers must provide SANDBOX_DIR before calling these functions. The routing
# functions derive CHANGES_DIR, INPUT_DIR, and OUTPUT_DIR from SANDBOX_DIR.
# They first try SESSION_STATE (written by sandbox-entrypoint after init), then
# fall back to dirs_resolve for host-side callers without a running container.

# No set -euo pipefail here — this file is always sourced, never executed directly.
# Safety settings are inherited from the parent script.

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
#   bundles       → $OUTPUT_DIR/bundles
#   diffs         → $OUTPUT_DIR/diffs
#
# Returns 1 with error message to stderr for unknown channel names.
resolve_channel_base_dir() {
  local CHANNEL="$1"
  case "$CHANNEL" in
    session)  echo "${CHANGES_DIR}/session" ;;
    autosave) echo "${CHANGES_DIR}/autosave" ;;
    bundles)  echo "${OUTPUT_DIR}/bundles" ;;
    diffs)    echo "${OUTPUT_DIR}/diffs" ;;
    *)
      echo "Error: unknown channel: $CHANNEL" >&2
      echo "  Valid: session, autosave, bundles, diffs" >&2
      return 1
      ;;
  esac
}

# =============================================================================
# Export path constructor (used by entrypoint and package_branch)
# =============================================================================

# export_path PARENT_DIR SUBDIR SESSION_ID [LABEL]
#
# Unified export path constructor. Replaces session_export_path and
# output_export_path. All paths anchored on export-time wall clock.
#
# Convention:
#   <PARENT_DIR>/<SUBDIR>/<EXPORT_TIME>-<SESSION_ID>/
#   <PARENT_DIR>/<SUBDIR>/<EXPORT_TIME>-<LABEL>-<SESSION_ID>/
#
# Args:
#   PARENT_DIR  — base directory (CHANGES_DIR, OUTPUT_DIR, or INPUT_DIR)
#   SUBDIR      — "session", "autosave", or "bundles"
#   SESSION_ID  — mandatory 6-char session hash
#   LABEL       — optional human-readable descriptor; inserted before SESSION_ID
#                 when present. Not used for autosave.
#
# Autosave is special: no EXPORT_TIME in the path (single directory, overwritten).
#   export_path "$CHANGES_DIR" "autosave" "a1b2c3"
#   → /.../session-diffs/autosave/a1b2c3
#
# All other subdirs include EXPORT_TIME:
#   export_path "$CHANGES_DIR" "session" "a1b2c3"
#   → /.../session-diffs/session/20260408-120000-a1b2c3
#
#   export_path "$OUTPUT_DIR" "bundles" "a1b2c3" "my-feature"
#   → /.../output/bundles/20260408-120000-my-feature-a1b2c3
export_path() {
  local PARENT_DIR="$1"
  local SUBDIR="$2"
  local SESSION_ID="$3"
  local LABEL="${4:-}"

  if [[ -z "$PARENT_DIR" || -z "$SUBDIR" || -z "$SESSION_ID" ]]; then
    echo "export_path: PARENT_DIR, SUBDIR, and SESSION_ID are required" >&2
    return 1
  fi

  local EXPORT_TIME
  EXPORT_TIME=$(date -u +%Y%m%d-%H%M%S)

  # Autosave: no EXPORT_TIME in path — single directory, overwritten each cycle
  if [[ "$SUBDIR" == "autosave" ]]; then
    echo "${PARENT_DIR}/autosave/${SESSION_ID}"
    return 0
  fi

  if [[ -n "$LABEL" ]]; then
    echo "${PARENT_DIR}/${SUBDIR}/${EXPORT_TIME}-${LABEL}-${SESSION_ID}"
  else
    echo "${PARENT_DIR}/${SUBDIR}/${EXPORT_TIME}-${SESSION_ID}"
  fi
}

# =============================================================================
# Channel resolution
# =============================================================================



# =============================================================================
# Directory resolution
# =============================================================================

# resolve_latest_dir BASE_DIR
#   Finds the most recently created subdirectory under BASE_DIR.
#   Returns 0 and prints the path on success, or returns 1 if BASE_DIR
#   does not exist or has no subdirectories.
resolve_latest_dir() {
  local _base="$1"
  if [[ ! -d "$_base" ]]; then return 1; fi
  local _latest
  _latest=$(find "$_base" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort | tail -n 1)
  if [[ -z "$_latest" ]]; then return 1; fi
  echo "$_latest"
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
    RESOLVED_DIR=$(resolve_latest_dir "$BASE_DIR") || {
      echo "Error: no session directories found under $BASE_DIR" >&2
      return 1
    }
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
    RESOLVED_DIR=$(resolve_latest_dir "$BASE_DIR") || {
      echo "Error: no session directories found under $BASE_DIR" >&2
      return 1
    }
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
