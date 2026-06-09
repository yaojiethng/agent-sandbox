#!/usr/bin/env bash
# src/libs/draft_state.sh
#
# Draft-state helpers: read, write, validate, and guard draft branch state.
# Sourced by draft.sh, confirm.sh, and reject.sh — not executed standalone.
#
# Provides:
#   draft_parse_folder_name       — parse SESSION_TS and branch from folder name
#   draft_guard_no_collision      — abort if draft branch already exists
#   draft_write_state             — produce .draft-state content string
#   draft_read_state_from_branch  — read .draft-state from branch tip as shell vars
#   draft_validate_branch         — validate current branch is a draft; print state vars
#   draft_resolve_commit_message  — resolve commit message from diff or .msg file

# =============================================================================
# draft_parse_folder_name — parse session identity from folder name
# =============================================================================

# Parse folder name format: <SESSION_TS>-<SANITIZED_HOST_BRANCH>[-<RUN_ID>]
# Sets SESSION_TS, SANITIZED_HOST_BRANCH, and RUN_ID in the caller's scope.
# RUN_ID is a 6-char hex hash appended as a suffix. When the last 6 chars
# after the final dash match [a-f0-9]{6}, they are parsed as RUN_ID.
draft_parse_folder_name() {
  local BASENAME="$1"
  SESSION_TS="${BASENAME:0:15}"
  SANITIZED_HOST_BRANCH="${BASENAME:16}"
  RUN_ID=""

  # Check if the last 6 chars after the final dash look like a RUN_ID
  if [[ "$SANITIZED_HOST_BRANCH" =~ -([a-f0-9]{6})$ ]]; then
    RUN_ID="${BASH_REMATCH[1]}"
    SANITIZED_HOST_BRANCH="${SANITIZED_HOST_BRANCH%-${RUN_ID}}"
  fi
}

# =============================================================================
# draft_guard_no_collision — abort if draft branch already exists
# =============================================================================

# Abort if a draft branch with the exact name already exists.
draft_guard_no_collision() {
  local PROJECT_DIR="$1"
  local BRANCH_NAME="$2"
  if git -C "$PROJECT_DIR" show-ref --verify --quiet "refs/heads/$BRANCH_NAME" 2>/dev/null; then
    echo "Error: draft branch already exists: $BRANCH_NAME" >&2
    echo "  Run 'make reject' to discard it, or use a different BRANCH_SUMMARY." >&2
    return 1
  fi
}

# =============================================================================
# draft_write_state — produce .draft-state content string
# =============================================================================

# Produce .draft-state content string; caller writes to file or commits.
draft_write_state() {
  local SOURCE_BRANCH="$1"
  local FROM_HASH="$2"
  local AUTHOR="$3"
  local SESSION_TS="$4"
  local HOST_BRANCH="$5"
  local DIFF_COUNT="$6"
  local EXPORTED_AT="$7"
  local DRAFTED_AT="$8"
  local RUN_ID="${9:-}"

  cat <<EOF
source_branch: ${SOURCE_BRANCH}
from_hash: ${FROM_HASH}
author: ${AUTHOR}
session_ts: ${SESSION_TS}
host_branch: ${HOST_BRANCH}
diff_count: ${DIFF_COUNT}
exported-at: ${EXPORTED_AT}
drafted-at: ${DRAFTED_AT}
run_id: ${RUN_ID}
EOF
}

# =============================================================================
# draft_read_state_from_branch — read .draft-state from branch tip
# =============================================================================

# Read .draft-state from the tip of the given branch.
# Prints shell variable assignments to stdout for eval by caller.
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

  while IFS=':' read -r KEY VALUE; do
    [[ -z "$KEY" ]] && continue
    KEY=$(echo "$KEY" | tr -d ' ' | tr '-' '_')
    VALUE=$(echo "$VALUE" | sed 's/^ *//')
    printf '%s="%s"\n' "$KEY" "$VALUE"
  done <<< "$STATE_CONTENT"
}

# =============================================================================
# draft_validate_branch — validate current branch is a proper draft branch
# =============================================================================

# Validate current branch is a proper draft branch.
# On success: prints variable assignments (including CURRENT_BRANCH) and returns 0.
# On failure: prints error to stderr and returns 1.
draft_validate_branch() {
  local PROJECT_DIR="$1"

  local CURRENT_BRANCH
  CURRENT_BRANCH=$(git -C "$PROJECT_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null) || {
    echo "Error: not in a git repository" >&2
    return 1
  }

  if [[ "$CURRENT_BRANCH" != draft/* ]]; then
    echo "Error: not on a draft branch (current: $CURRENT_BRANCH)" >&2
    return 1
  fi

  local STATE_CONTENT
  STATE_CONTENT=$(git -C "$PROJECT_DIR" show "${CURRENT_BRANCH}:.draft-state" 2>/dev/null) || {
    echo "Error: .draft-state not found on branch: $CURRENT_BRANCH" >&2
    return 1
  }

  while IFS=':' read -r KEY VALUE; do
    [[ -z "$KEY" ]] && continue
    KEY=$(echo "$KEY" | tr -d ' ' | tr '-' '_')
    VALUE=$(echo "$VALUE" | sed 's/^ *//')
    printf -v "$KEY" '%s' "$VALUE"
    printf '%s="%s"\n' "$KEY" "$VALUE"
  done <<< "$STATE_CONTENT"

  if [[ -z "${from_hash:-}" ]]; then
    echo "Error: .draft-state on $CURRENT_BRANCH is missing 'from_hash' field" >&2
    return 1
  fi

  # Find .draft-state commit by message — it may not be the first commit after
  # from_hash if the user ran git rebase -i (which is the recommended workflow
  # for shaping commits before confirm).
  local DRAFT_STATE_COMMIT
  DRAFT_STATE_COMMIT=$(git -C "$PROJECT_DIR" log "${from_hash}..${CURRENT_BRANCH}" --reverse --format="%H" --grep="^\.draft-state$" 2>/dev/null | head -1)

  if [[ -z "$DRAFT_STATE_COMMIT" ]]; then
    echo "Warning: .draft-state commit not found between ${from_hash:0:7}..${CURRENT_BRANCH}" >&2
    echo "  The commit may have been dropped during rebase. Skipping drop step." >&2
    echo "DRAFT_STATE_COMMIT="
  else
    echo "DRAFT_STATE_COMMIT=$DRAFT_STATE_COMMIT"
  fi

  echo "CURRENT_BRANCH=$CURRENT_BRANCH"
}

# =============================================================================
# draft_resolve_commit_message — resolve commit message for a diff file
# =============================================================================

# draft_resolve_commit_message DIFF_FILE
#
# Returns the commit message to use for a given diff file, following this
# priority:
#   1. Sibling .msg file (full original commit message)
#   2. Subject extracted from filename (NNNN-SHA-<subject>.diff)
#   3. Fallback: "Apply <basename>"
#
# Output:
#   stdout — the resolved commit message
#
# Returns:
#   0 always
draft_resolve_commit_message() {
  local DIFF_FILE="$1"
  local MSG_FILE="${DIFF_FILE%.diff}.msg"

  # Priority 1: sibling .msg file
  if [[ -f "$MSG_FILE" && -s "$MSG_FILE" ]]; then
    cat "$MSG_FILE"
    return 0
  fi

  local BNAME
  BNAME=$(basename "$DIFF_FILE")

  # Priority 2: extract subject from filename (NNNN-<sha>-<subject>.diff)
  # The filename structure is: NNNN-<fullsha>[-<sanitized_subject>].diff
  # SHA is hex-only (no dashes), so dashes are reliable separators.
  local STEM="${BNAME%.diff}"          # strip .diff
  local REST="${STEM#*-}"              # strip NNNN- prefix, leaving SHA[-subject]
  if [[ "$REST" == *-* ]]; then
    # Has a subject portion: strip SHA (first dash-separated token)
    local SUBJECT="${REST#*-}"          # strip SHA-
    if [[ -n "$SUBJECT" ]]; then
      # Clean: trim leading underscores, collapse consecutive, trim trailing
      while [[ "$SUBJECT" == _* ]]; do SUBJECT="${SUBJECT#_}"; done
      while [[ "$SUBJECT" == *__* ]]; do SUBJECT="${SUBJECT//__/_}"; done
      while [[ "$SUBJECT" == *_ ]]; do SUBJECT="${SUBJECT%_}"; done
      # Convert remaining underscores to spaces
      SUBJECT="${SUBJECT//_/ }"
      echo "$SUBJECT"
      return 0
    fi
  fi

  # Priority 3: fallback
  echo "Apply ${BNAME}"
}
