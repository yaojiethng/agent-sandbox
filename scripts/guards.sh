#!/usr/bin/env bash
# scripts/guards.sh
# Git workflow guard functions  --  validate repo state and clear stale locks.
# Sourced by host-side workflow files (draft, apply) and agent-sandbox.sh.
#
# Provides:
#   validate_project_dir     --  check PROJECT_DIR exists, is git repo, has commits
#   draft_clear_stale_lock   --  remove stale .git/index.lock

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
