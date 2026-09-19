#!/usr/bin/env bash
# scripts/guards.sh
# Git workflow guard functions  --  validate repo state and clear stale locks.
# Sourced by host-side workflow files (draft, apply) and agent-sandbox.sh.
#
# Provides:
#   validate_project_dir     --  check PROJECT_DIR exists, is git repo, has commits
#   draft_clear_stale_lock   --  remove stale .git/index.lock
#   require_clean_working_tree -- fail when the working tree is dirty

# validate_project_dir PROJECT_DIR
#   Checks PROJECT_DIR exists, is a git repository, and has at least one commit.
#   Returns 1 with error message to stderr on failure.
validate_project_dir() {
  local PROJECT_DIR="$1"

  if [[ ! -d "$PROJECT_DIR" ]]; then
    echo "Error: PROJECT_DIR does not exist: $PROJECT_DIR" >&2
    return 1
  fi

  if ! git -C "$PROJECT_DIR" rev-parse --git-dir >/dev/null 2>&1; then
    echo "Error: $PROJECT_DIR is not a git repository" >&2
    return 1
  fi

  if ! git -C "$PROJECT_DIR" rev-parse HEAD >/dev/null 2>&1; then
    echo "Error: $PROJECT_DIR has no commits - cannot apply patch" >&2
    return 1
  fi
}

# require_clean_working_tree PROJECT_DIR [LABEL]
# Fail when the working tree is not clean (uncommitted, staged, or untracked
# changes present). LABEL names the caller for the error message. Returns 1
# with a commit-or-stash hint on stderr when the tree is dirty.
# Dirty is the empty remainder of `status --porcelain`.
require_clean_working_tree() {
  local dir="$1"
  local label="${2:-operation}"
  if [[ -n "$(git -C "$dir" status --porcelain 2>/dev/null)" ]]; then
    echo "Error: $label requires a clean working tree but uncommitted changes are present." >&2
    echo "  Commit or stash your changes, then retry." >&2
    return 1
  fi
}

# draft_clear_stale_lock PROJECT_DIR
# Check for and remove a stale .git/index.lock.
draft_clear_stale_lock() {
  local PROJECT_DIR="$1"
  local LOCKFILE="$PROJECT_DIR/.git/index.lock"
  if [[ -f "$LOCKFILE" ]]; then
    local LOCK_HELD=false
    if command -v lsof >/dev/null 2>&1; then
      if lsof "$LOCKFILE" >/dev/null 2>&1; then
        LOCK_HELD=true
      fi
    fi
    if [[ "$LOCK_HELD" == true ]]; then
      echo "Error: .git/index.lock is held by another git process" >&2
      echo "  File: $LOCKFILE" >&2
      echo "  Ensure no other git process is running and retry." >&2
      return 1
    fi
    echo "Warning: removing stale .git/index.lock" >&2
    rm -f "$LOCKFILE"
  fi
}
