#!/usr/bin/env bash
# src/libs/draft_state.sh
#
# Draft branch record helpers: write, clear, read, and validate the
# branch-local record. Sourced by draft.sh, confirm.sh, and reject.sh  --  not
# executed standalone.
#
# Provides:
#   draft_parse_folder_name        --  parse SESSION_TS and branch from folder name
#   draft_guard_no_collision       --  abort if the exact draft branch ref exists
#   draft_record_write             --  write source_branch and fork_point to git config
#   draft_record_clear             --  remove those two keys
#   draft_record_read              --  read one key from the branch record
#   draft_validate_branch          --  validate current branch is a draft; set record vars
#   draft_resolve_commit_message   --  resolve commit message from diff or .msg file

# The record lives under branch.<draft>.*. The keys are branch-local because
# git removes the section when the branch is deleted.
_DRAFT_RECORD_SOURCE_KEY="agent-sandbox-source"
_DRAFT_RECORD_FORK_KEY="agent-sandbox-fork"

# =============================================================================
# draft_parse_folder_name  --  parse session identity from folder name
# =============================================================================

# Parse folder name format: <SESSION_TS>-<SANITIZED_HOST_BRANCH>[-<SESSION_ID>]
# Sets SESSION_TS, SANITIZED_HOST_BRANCH, and SESSION_ID in the caller's scope.
# SESSION_ID is a 6-char hex hash appended as a suffix. When the last 6 chars
# after the final dash match [a-f0-9]{6}, they are parsed as SESSION_ID.
draft_parse_folder_name() {
  local BASENAME="$1"
  # SESSION_TS is consumed by the caller; ShellCheck checks this file alone.
  # shellcheck disable=SC2034
  SESSION_TS="${BASENAME:0:15}"
  SANITIZED_HOST_BRANCH="${BASENAME:16}"
  SESSION_ID=""

  # Check if the last 6 chars after the final dash look like a SESSION_ID
  if [[ "$SANITIZED_HOST_BRANCH" =~ -([a-f0-9]{6})$ ]]; then
    SESSION_ID="${BASH_REMATCH[1]}"
    SANITIZED_HOST_BRANCH="${SANITIZED_HOST_BRANCH%-${SESSION_ID}}"
  fi
}

# =============================================================================
# draft_guard_no_collision  --  abort if the exact draft branch ref exists
# =============================================================================

# Abort if a draft branch with the exact name already exists. The branch name
# is the draft identity; a different name may coexist.
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
# draft_record_write  --  write the branch-local draft record
# =============================================================================

# draft_record_write PROJECT_DIR BRANCH_NAME SOURCE_BRANCH FORK_POINT
#
# Writes the two record keys before the branch exists. If the second write
# fails, the first is removed so no partial record remains.
draft_record_write() {
  local PROJECT_DIR="$1"
  local BRANCH_NAME="$2"
  local SOURCE_BRANCH="$3"
  local FORK_POINT="$4"

  local SOURCE_KEY="branch.${BRANCH_NAME}.${_DRAFT_RECORD_SOURCE_KEY}"
  local FORK_KEY="branch.${BRANCH_NAME}.${_DRAFT_RECORD_FORK_KEY}"

  if ! git -C "$PROJECT_DIR" config --local "$SOURCE_KEY" "$SOURCE_BRANCH"; then
    echo "Error: failed to write draft record for $BRANCH_NAME" >&2
    return 1
  fi
  if ! git -C "$PROJECT_DIR" config --local "$FORK_KEY" "$FORK_POINT"; then
    git -C "$PROJECT_DIR" config --local --unset-all "$SOURCE_KEY" 2>/dev/null || true
    echo "Error: failed to write draft record for $BRANCH_NAME" >&2
    return 1
  fi
}

# =============================================================================
# draft_record_clear  --  remove the branch-local draft record
# =============================================================================

# draft_record_clear PROJECT_DIR BRANCH_NAME
#
# Removes both keys. The success path relies on `git branch -D`; this helper
# covers a branch that was never created or a rollback that needs to unwind it.
draft_record_clear() {
  local PROJECT_DIR="$1"
  local BRANCH_NAME="$2"

  git -C "$PROJECT_DIR" config --local --unset-all \
    "branch.${BRANCH_NAME}.${_DRAFT_RECORD_SOURCE_KEY}" 2>/dev/null || true
  git -C "$PROJECT_DIR" config --local --unset-all \
    "branch.${BRANCH_NAME}.${_DRAFT_RECORD_FORK_KEY}" 2>/dev/null || true
  return 0
}

# =============================================================================
# draft_record_read  --  read one key from the branch record
# =============================================================================

# draft_record_read PROJECT_DIR BRANCH KEY
#
# KEY is `source` or `fork`. Prints the recorded value and returns 0; prints
# nothing and returns 1 when the key is absent.
draft_record_read() {
  local PROJECT_DIR="$1"
  local BRANCH="$2"
  local KEY="$3"

  local _key
  case "$KEY" in
    source) _key="$_DRAFT_RECORD_SOURCE_KEY" ;;
    fork) _key="$_DRAFT_RECORD_FORK_KEY" ;;
    *)
      echo "Error: unknown draft record key: $KEY" >&2
      return 1
      ;;
  esac

  git -C "$PROJECT_DIR" config --local --get "branch.${BRANCH}.${_key}" 2>/dev/null
}

# =============================================================================
# draft_validate_branch  --  validate current branch is a proper draft branch
# =============================================================================

# Validate the current branch is a draft branch with a source record. On
# success, sets DRAFT_SOURCE_BRANCH and DRAFT_CURRENT_BRANCH in the caller's
# scope and returns 0. The source branch is not required to still exist; the
# caller decides whether that is fatal.
# On failure: prints an error to stderr and returns 1.
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

  local source_branch=""
  if ! source_branch=$(draft_record_read "$PROJECT_DIR" "$CURRENT_BRANCH" source); then
    if draft_record_read "$PROJECT_DIR" "$CURRENT_BRANCH" fork >/dev/null 2>&1; then
      echo "Error: draft record on $CURRENT_BRANCH is missing 'source_branch'" >&2
    else
      echo "Error: draft record not found on branch: $CURRENT_BRANCH" >&2
    fi
    return 1
  fi
  if [[ -z "$source_branch" ]]; then
    echo "Error: draft record on $CURRENT_BRANCH is missing 'source_branch'" >&2
    return 1
  fi

  # Both values are consumed by the importing workflow; ShellCheck checks this
  # file alone.
  # shellcheck disable=SC2034
  DRAFT_SOURCE_BRANCH="$source_branch"
  # shellcheck disable=SC2034
  DRAFT_CURRENT_BRANCH="$CURRENT_BRANCH"
}

# =============================================================================
# draft_resolve_commit_message  --  resolve commit message for a diff file
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
#   stdout  --  the resolved commit message
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
