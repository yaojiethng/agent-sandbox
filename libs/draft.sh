#!/usr/bin/env bash
# libs/draft.sh
#
# Shared draft branch management utilities for apply_workspace.sh.
# Sourced by apply_workspace.sh — not executed standalone.
#
# Depends on: git, standard shell utilities.

set -euo pipefail

# -------------------------
# Resolve latest export folder
# -------------------------
# Find the lexicographically last directory entry under BASE_DIR.
# Returns the full path to the selected directory.
draft_resolve_latest_export() {
  local BASE_DIR="$1"
  if [[ ! -d "$BASE_DIR" ]]; then
    echo "Error: directory not found: $BASE_DIR" >&2
    return 1
  fi

  local LATEST
  LATEST=$(find "$BASE_DIR" -mindepth 1 -maxdepth 1 -type d | sort | tail -n 1)
  if [[ -z "$LATEST" ]]; then
    echo "Error: no export folders found under $BASE_DIR" >&2
    return 1
  fi
  echo "$LATEST"
}

# -------------------------
# Parse export folder name
# -------------------------
# Folder name format: <EXPORT_TIME>-<SANITIZED_HOST_BRANCH>-<SESSION_TS>
# EXPORT_TIME is fixed width: YYYYMMDD-HHMMSS (15 chars + dash = 16)
# SESSION_TS is fixed width: YYYYMMDD-HHMMSS (15 chars)
# SANITIZED_HOST_BRANCH is everything between them.
#
# Sets variables in caller scope:
#   EXPORT_TIME, SANITIZED_HOST_BRANCH, SESSION_TS
#
draft_parse_folder_name() {
  local BASENAME="$1"

  # Extract EXPORT_TIME (first 15 chars: YYYYMMDD-HHMMSS)
  EXPORT_TIME="${BASENAME:0:15}"

  # Extract SESSION_TS (last 15 chars: YYYYMMDD-HHMMSS)
  SESSION_TS="${BASENAME: -15}"

  # Extract SANITIZED_HOST_BRANCH (everything between the two timestamps and their delimiters)
  # Format: YYYYMMDD-HHMMSS-<branch>-YYYYMMDD-HHMMSS
  # Remove first 16 chars (EXPORT_TIME + trailing dash) and last 16 chars (leading dash + SESSION_TS)
  local REMAINING="${BASENAME:16}"
  SANITIZED_HOST_BRANCH="${REMAINING%-*}"
}

# -------------------------
# Draft branch collision guard
# -------------------------
# Abort with a clear error if a branch with the exact name already exists.
draft_guard_no_collision() {
  local PROJECT_DIR="$1"
  local BRANCH_NAME="$2"

  if git -C "$PROJECT_DIR" show-ref --verify --quiet "refs/heads/$BRANCH_NAME" 2>/dev/null; then
    echo "Error: draft branch already exists: $BRANCH_NAME" >&2
    echo "  Run 'make reject' to discard it, or use a different BRANCH_SUMMARY." >&2
    return 1
  fi
}

# -------------------------
# Write .draft-state file content
# -------------------------
# Produces the content string; caller writes to file or commits.
draft_write_state() {
  local SOURCE_BRANCH="$1"
  local FROM_HASH="$2"
  local AUTHOR="$3"
  local SESSION_TS="$4"
  local HOST_BRANCH="$5"
  local DIFF_COUNT="$6"
  local EXPORTED_AT="$7"
  local DRAFTED_AT="$8"

  cat <<EOF
source_branch: ${SOURCE_BRANCH}
from_hash: ${FROM_HASH}
author: ${AUTHOR}
session_ts: ${SESSION_TS}
host_branch: ${HOST_BRANCH}
diff_count: ${DIFF_COUNT}
exported-at: ${EXPORTED_AT}
drafted-at: ${DRAFTED_AT}
EOF
}

# -------------------------
# Read .draft-state from a branch
# -------------------------
# Reads .draft-state from the tip of the given branch.
# Sets variables in caller scope by sourcing the content.
# Each line becomes: KEY="value"
draft_read_state_from_branch() {
  local PROJECT_DIR="$1"
  local BRANCH_NAME="$2"

  if ! git -C "$PROJECT_DIR" show-ref --verify --quiet "refs/heads/$BRANCH_NAME" 2>/dev/null; then
    echo "Error: branch does not exist: $BRANCH_NAME" >&2
    return 1
  fi

  local STATE_CONTENT
  STATE_CONTENT=$(git -C "$PROJECT_DIR" show "${BRANCH_NAME}:.draft-state" 2>/dev/null) || {
    echo "Error: .draft-state not found on branch: $BRANCH_NAME" >&2
    return 1
  }

  # Parse key: value lines into shell variables
  while IFS=':' read -r KEY VALUE; do
    [[ -z "$KEY" ]] && continue
    KEY=$(echo "$KEY" | tr -d ' ')
    VALUE=$(echo "$VALUE" | sed 's/^ *//')
    printf '%s="%s"\n' "$KEY" "$VALUE"
  done <<< "$STATE_CONTENT"
}
