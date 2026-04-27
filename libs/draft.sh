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
  # Hyphens in keys are converted to underscores so they are valid shell identifiers.
  while IFS=':' read -r KEY VALUE; do
    [[ -z "$KEY" ]] && continue
    KEY=$(echo "$KEY" | tr -d ' ' | tr '-' '_')
    VALUE=$(echo "$VALUE" | sed 's/^ *//')
    printf '%s="%s"\n' "$KEY" "$VALUE"
  done <<< "$STATE_CONTENT"
}

# -------------------------
# Validate current branch is a proper draft branch
# -------------------------
# Performs three checks:
#   1. Current branch name starts with "draft/"
#   2. .draft-state file exists at the branch tip
#   3. The first commit on the branch (after from_hash) has message ".draft-state"
#
# On success: sets shell variables from .draft-state in caller scope and returns 0.
# On failure: prints descriptive error to stderr and returns 1.
#
draft_validate_branch() {
  local PROJECT_DIR="$1"

  local CURRENT_BRANCH
  CURRENT_BRANCH=$(git -C "$PROJECT_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null) || {
    echo "Error: not in a git repository" >&2
    return 1
  }

  # Check 1: branch name
  if [[ "$CURRENT_BRANCH" != draft/* ]]; then
    echo "Error: not on a draft branch (current: $CURRENT_BRANCH)" >&2
    return 1
  fi

  # Check 2: .draft-state exists on branch
  local STATE_CONTENT
  STATE_CONTENT=$(git -C "$PROJECT_DIR" show "${CURRENT_BRANCH}:.draft-state" 2>/dev/null) || {
    echo "Error: .draft-state not found on branch: $CURRENT_BRANCH" >&2
    return 1
  }

  # Set variables in function scope and print for caller
  # Hyphens in keys are converted to underscores so they are valid shell identifiers.
  while IFS=':' read -r KEY VALUE; do
    [[ -z "$KEY" ]] && continue
    KEY=$(echo "$KEY" | tr -d ' ' | tr '-' '_')
    VALUE=$(echo "$VALUE" | sed 's/^ *//')
    printf -v "$KEY" '%s' "$VALUE"
    printf '%s="%s"\n' "$KEY" "$VALUE"
  done <<< "$STATE_CONTENT"

  # Check 3: first commit after from_hash has message ".draft-state"
  if [[ -z "${from_hash:-}" ]]; then
    echo "Error: .draft-state on $CURRENT_BRANCH is missing 'from_hash' field" >&2
    return 1
  fi

  local FIRST_COMMIT_MSG
  FIRST_COMMIT_MSG=$(git -C "$PROJECT_DIR" rev-list "${from_hash}..${CURRENT_BRANCH}" --reverse --format=%s | grep -v '^commit ' | head -n 1)

  if [[ "$FIRST_COMMIT_MSG" != ".draft-state" ]]; then
    echo "Error: first commit on draft branch $CURRENT_BRANCH is not '.draft-state' (got: $FIRST_COMMIT_MSG)" >&2
    return 1
  fi

  # Export current branch name for downstream use
  echo "CURRENT_BRANCH=$CURRENT_BRANCH"
}
